#!/bin/bash
# Restore one namespace from its snapshot. Live files move aside and come
# back if the copy fails. Usage: restore.sh namespace [snapshot]
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/lib.sh"

ns=${1:?namespace}
snap=${2:-latest}
target="${COPY_DIR}/restore"
committed=0
asides=()

rollback() {
  local aside base dest
  for aside in "${asides[@]}"; do
    [[ -d "$aside" ]] || continue
    base=$(basename "$aside" .aside)
    base=${base#.}
    dest="${VOLUMES_RW}/${base}"
    mkdir -p "$dest"
    find "$dest" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
    find "$aside" -mindepth 1 -maxdepth 1 -exec mv -t "$dest" {} +
  done
}

cleanup() {
  local rc=$?
  if [[ "$committed" -ne 1 ]]; then
    rollback || true
  else
    local aside
    for aside in "${asides[@]}"; do
      rm -rf "$aside" || true
    done
  fi
  thaw_all || true
  rm -rf "$target" || true
  exit "$rc"
}
trap cleanup EXIT

lock_backup
repo_ready

rm -rf "$target"
mkdir -p "$target"
restore_args=(restore "$snap" --target "$target" --tag "$ns")
if [[ "$snap" == latest ]]; then
  restore_args+=(--host helios)
fi
restic "${restore_args[@]}"

mapfile -t found < <(find "$target" -type d -name "pvc-*_${ns}_*")
if [[ ${#found[@]} -eq 0 ]]; then
  printf 'no claim directories for %s in snapshot %s\n' "$ns" "$snap" >&2
  exit 1
fi

thaw_all
: > "$FROZEN"
for dir in "${found[@]}"; do
  base=$(basename "$dir")
  rest=${base#*_}
  claim=${rest#"${ns}_"}
  freeze_claim "$ns" "$claim"
done
sync

for dir in "${found[@]}"; do
  base=$(basename "$dir")
  live_rw="${VOLUMES_RW}/${base}"
  if [[ ! -d "$live_rw" ]]; then
    printf 'claim is not writable at %s\n' "$live_rw" >&2
    exit 1
  fi
  aside="${VOLUMES_RW}/.${base}.aside"
  rm -rf "$aside"
  mkdir -p "$aside"
  asides+=("$aside")
  find "$live_rw" -mindepth 1 -maxdepth 1 -exec mv -t "$aside" {} +
  cp -a "${dir}/." "$live_rw/"
done

committed=1
kill_frozen
