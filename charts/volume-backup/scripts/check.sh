#!/bin/bash
# Arguments are passed to restic check.
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/lib.sh"

rid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || true)
lock_backup
ping_hc "${HEALTHCHECKS_URL_CHECK_START:-}" "$rid"
if ! repo_ready; then
  ping_hc "${HEALTHCHECKS_URL_CHECK_FAIL:-}" "$rid"
  exit 1
fi
if ! restic check "$@"; then
  ping_hc "${HEALTHCHECKS_URL_CHECK_FAIL:-}" "$rid"
  exit 1
fi
ping_hc "${HEALTHCHECKS_URL_CHECK_SUCCESS:-}" "$rid"
