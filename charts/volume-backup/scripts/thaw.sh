#!/bin/bash
# Unfreeze anything still frozen, and drop the local copy. Safe to run twice.
set -uo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/lib.sh"
thaw_all
rm -rf "${COPY_DIR}/data/pvc-"* "${COPY_DIR}/restore"
mkdir -p "${COPY_DIR}/data"
