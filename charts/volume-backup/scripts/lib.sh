# shellcheck shell=bash
# k3s on cgroup v2 puts each pod in a systemd slice named from its UID.
# Freezing that slice stops every process in the pod.

KUBECTL=${KUBECTL:-/opt/bin/kubectl}
VOLUMES=${VOLUMES:-/mnt/volumes}
VOLUMES_RW=${VOLUMES_RW:-/mnt/volumes-rw}
COPY_DIR=${COPY_DIR:-/mnt/copy}
CGROUP=${CGROUP:-/sys/fs/cgroup}
EXCLUDE_FILE=${EXCLUDE_FILE:-/scripts/exclude}
FROZEN=${FROZEN:-/run/frozen-cgroups}
FROZEN_DISK=${FROZEN_DISK:-/mnt/copy/.frozen}

excluded() {
  local ns=$1 claim=$2
  [[ -f "$EXCLUDE_FILE" ]] || return 1
  grep -Fqx "${ns}/${claim}" "$EXCLUDE_FILE"
}

cgroup_for() {
  local uid=$1 qos=$2
  local u=${uid//-/_}
  local path found
  case "$qos" in
    Guaranteed)
      path="$CGROUP/kubepods.slice/kubepods-guaranteed.slice/kubepods-guaranteed-pod${u}.slice"
      ;;
    BestEffort)
      path="$CGROUP/kubepods.slice/kubepods-besteffort.slice/kubepods-besteffort-pod${u}.slice"
      ;;
    *)
      path="$CGROUP/kubepods.slice/kubepods-burstable.slice/kubepods-burstable-pod${u}.slice"
      ;;
  esac
  if [[ -f "$path/cgroup.freeze" ]]; then
    printf '%s\n' "$path"
    return 0
  fi
  found=$(find "$CGROUP/kubepods.slice" -maxdepth 3 -type d -name "*pod${u}.slice" 2>/dev/null | head -n 1 || true)
  if [[ -n "$found" && -f "$found/cgroup.freeze" ]]; then
    printf '%s\n' "$found"
    return 0
  fi
  return 1
}

record_freeze() {
  local cg=$1
  mkdir -p "$COPY_DIR"
  printf '%s\n' "$cg" >> "$FROZEN"
  printf '%s\n' "$cg" >> "$FROZEN_DISK"
  printf '1\n' > "$cg/cgroup.freeze"
}

thaw_file() {
  local file=$1 cg
  [[ -f "$file" ]] || return 0
  while IFS= read -r cg; do
    [[ -z "$cg" ]] && continue
    if [[ -f "$cg/cgroup.freeze" ]]; then
      printf '0\n' > "$cg/cgroup.freeze" || true
    fi
  done < "$file"
  rm -f "$file"
}

thaw_all() {
  thaw_file "$FROZEN"
  thaw_file "$FROZEN_DISK"
}

# Kills writers while their cgroup is frozen.
# A thawed process still has the previous SQLite inode open and would keep serving the old database.
# cgroup.procs on the pod slice is empty, because the containers are child scopes.
# cgroup.kill covers that whole subtree.
kill_frozen() {
  local cg
  [[ -f "$FROZEN" ]] || return 0
  while IFS= read -r cg; do
    [[ -z "$cg" ]] && continue
    if [[ ! -w "$cg/cgroup.kill" ]]; then
      printf 'no cgroup.kill at %s\n' "$cg" >&2
      return 1
    fi
    printf '1\n' > "$cg/cgroup.kill"
  done < "$FROZEN"
}

claim_dir() {
  local ns=$1 claim=$2
  local matches=() dir
  shopt -s nullglob
  for dir in "$VOLUMES"/pvc-*"_${ns}_${claim}"; do
    [[ -d "$dir" ]] && matches+=("$dir")
  done
  shopt -u nullglob
  if [[ ${#matches[@]} -ne 1 ]]; then
    printf 'expected one directory for %s/%s, found %s\n' "$ns" "$claim" "${#matches[@]}" >&2
    return 1
  fi
  printf '%s\n' "${matches[0]}"
}

pods_for_claim() {
  local ns=$1 claim=$2 out uid qos name claims
  if ! out=$("$KUBECTL" get pods -n "$ns" --field-selector=status.phase=Running -o jsonpath='{range .items[*]}{.metadata.uid}{" "}{.status.qosClass}{" "}{.metadata.name}{" "}{range .spec.volumes[*]}{.persistentVolumeClaim.claimName}{","}{end}{"\n"}{end}'); then
    printf 'listing pods in %s failed\n' "$ns" >&2
    return 1
  fi
  while read -r uid qos name claims; do
    [[ -z "${uid:-}" ]] && continue
    [[ "$name" == "${HOSTNAME:-}" ]] && continue
    case ",${claims}" in
      *",${claim},"*) printf '%s %s\n' "$uid" "$qos" ;;
    esac
  done <<<"$out"
}

freeze_claim() {
  local ns=$1 claim=$2 uid qos cg lines
  if ! lines=$(pods_for_claim "$ns" "$claim"); then
    return 1
  fi
  while read -r uid qos; do
    [[ -z "${uid:-}" ]] && continue
    if ! cg=$(cgroup_for "$uid" "$qos"); then
      printf 'no cgroup for pod %s\n' "$uid" >&2
      return 1
    fi
    record_freeze "$cg"
  done <<<"$lines"
}

bound_claims() {
  "$KUBECTL" get pvc -A -o jsonpath='{range .items[?(@.status.phase=="Bound")]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}'
}

# Holds the fd for the life of the process.
# Backup and restore share the hostPath.
lock_backup() {
  mkdir -p /run/lock
  exec 9>/run/lock/backup.lock
  if ! flock -n 9; then
    printf 'backup or restore already holds the lock\n' >&2
    return 1
  fi
}

ping_hc() {
  local url=$1 rid=$2
  curl -fsS -m 10 --retry 3 -X POST "${url:-}?rid=${rid}" || true
}

repo_ready() {
  if ! restic cat config >/dev/null; then
    printf 'repository is not reachable\n' >&2
    return 1
  fi
}

# Flushes dirty pages before the freeze.
# A namespace without Postgres is a no-op.
checkpoint_postgres() {
  local ns=$1 name containers out
  if ! out=$("$KUBECTL" get pods -n "$ns" --field-selector=status.phase=Running -o jsonpath='{range .items[*]}{.metadata.name}{" "}{range .spec.containers[*]}{.name}{","}{end}{"\n"}{end}'); then
    printf 'listing pods in %s failed\n' "$ns" >&2
    return 1
  fi
  while read -r name containers; do
    [[ -z "${name:-}" ]] && continue
    case ",${containers}" in
      *,postgres,*)
        # POSTGRES_USER and POSTGRES_DB are set inside the database container.
        # shellcheck disable=SC2016
        "$KUBECTL" exec -n "$ns" "$name" -c postgres -- \
          sh -c 'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CHECKPOINT"' \
          || return 1
        ;;
    esac
  done <<<"$out"
}
