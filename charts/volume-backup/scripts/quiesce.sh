#!/bin/bash
# Freeze writers, sync, copy the claim directories, then unfreeze.
# restic uploads that copy after this returns, so the live
# claims accept writes again during the upload.
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/lib.sh"

fail() {
  trap - ERR
  thaw_all || true
  rm -rf "${COPY_DIR}/data/pvc-"* || true
  curl -fsS -m 10 --retry 3 -X POST "${HEALTHCHECKS_URL_BACKUP_FAIL:-}?rid=${RID:-}" || true
  exit 1
}

if ! restic cat config >/dev/null; then
  printf 'repository is not reachable\n' >&2
  fail
fi

trap fail ERR

thaw_all
mkdir -p "${COPY_DIR}/data"
: > "$FROZEN"
# rm -f leaves directories in place, and cp -a would merge into them.
rm -rf "${COPY_DIR}/data/pvc-"*

copy_list=$(mktemp)
out=$(bound_claims)

while read -r ns claim; do
  [[ -z "${ns:-}" ]] && continue
  if excluded "$ns" "$claim"; then
    continue
  fi
  dir=$(claim_dir "$ns" "$claim")
  freeze_claim "$ns" "$claim"
  printf '%s\n' "$dir" >> "$copy_list"
done <<<"$out"

sync
while IFS= read -r dir; do
  [[ -z "$dir" ]] && continue
  cp -a "$dir" "${COPY_DIR}/data/"
done < "$copy_list"
rm -f "$copy_list"

thaw_all
trap - ERR
