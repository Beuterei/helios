#!/bin/bash
# Replace one live claim directory with a snapshot, while its writers are frozen.
# Usage: restore.sh namespace claim [snapshot]
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/lib.sh"

ns=${1:?namespace}
claim=${2:?claim}
snap=${3:-latest}
target="${COPY_DIR}/restore"

if [[ -f /run/lock/backup.lock ]]; then
  printf 'a backup is running\n' >&2
  exit 1
fi

cleanup() {
  thaw_all || true
  rm -rf "$target" || true
}
trap cleanup EXIT

if ! restic cat config >/dev/null; then
  printf 'repository is not reachable\n' >&2
  exit 1
fi

live=$(claim_dir "$ns" "$claim")
thaw_all
: > "$FROZEN"
freeze_claim "$ns" "$claim"
sync

rm -rf "$target"
mkdir -p "$target"
# * does not cross '/'. Match the claim directory and everything under it.
restore_args=(
  restore "$snap" --target "$target"
  --include "**/pvc-*_${ns}_${claim}"
  --include "**/pvc-*_${ns}_${claim}/**"
)
if [[ "$snap" == latest ]]; then
  restore_args+=(--host helios --tag k3s-volumes)
fi
restic "${restore_args[@]}"

mapfile -t found < <(find "$target" -type d -name "pvc-*_${ns}_${claim}")
if [[ ${#found[@]} -ne 1 ]]; then
  printf 'expected one restored directory for %s/%s, found %s\n' "$ns" "$claim" "${#found[@]}" >&2
  exit 1
fi

find "$live" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
cp -a "${found[0]}/." "$live/"
sync
