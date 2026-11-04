#!/bin/bash
# One namespace at a time: checkpoint, freeze, copy, thaw, then one restic
# snapshot tagged with the namespace. Writers stay frozen only for that copy.
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/lib.sh"

rid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || true)
lock_backup

fail() {
  trap - ERR
  thaw_all || true
  ping_hc "${HEALTHCHECKS_URL_BACKUP_FAIL:-}" "$rid"
  exit 1
}
trap fail ERR

ping_hc "${HEALTHCHECKS_URL_BACKUP_START:-}" "$rid"
if ! restic cat config >/dev/null; then
  restic init
fi

declare -A claims_of
claims=$(bound_claims)
while read -r ns claim; do
  [[ -z "${ns:-}" ]] && continue
  if excluded "$ns" "$claim"; then
    continue
  fi
  claims_of[$ns]+="${claim}"$'\n'
done <<<"$claims"

if [[ ${#claims_of[@]} -eq 0 ]]; then
  printf 'no claims to copy\n' >&2
  fail
fi

while read -r ns; do
  [[ -z "$ns" ]] && continue
  checkpoint_postgres "$ns"
  thaw_all
  : > "$FROZEN"
  while read -r claim; do
    [[ -z "$claim" ]] && continue
    freeze_claim "$ns" "$claim"
  done <<<"${claims_of[$ns]}"
  sync
  rm -rf "${COPY_DIR}/data/pvc-"*
  mkdir -p "${COPY_DIR}/data"
  while read -r claim; do
    [[ -z "$claim" ]] && continue
    cp -a "$(claim_dir "$ns" "$claim")" "${COPY_DIR}/data/"
  done <<<"${claims_of[$ns]}"
  thaw_all
  restic backup "${COPY_DIR}/data" --tag "$ns" --host helios --exclude '*.tmp' --verbose
done < <(printf '%s\n' "${!claims_of[@]}" | sort)

# This repository is shared with other hosts. --host keeps their snapshots out of
# retention. Group by host and tags so each namespace is its own history.
restic forget --host helios --group-by host,tags --keep-last 30 --keep-daily 7 --keep-weekly 5 --keep-monthly 12
thaw_all
trap - ERR
ping_hc "${HEALTHCHECKS_URL_BACKUP_SUCCESS:-}" "$rid"
