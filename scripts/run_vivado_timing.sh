#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
if ! command -v vivado >/dev/null 2>&1; then
    printf 'ERROR: Vivado with Artix-7 device support is required. Source its settings script first.\n' >&2
    exit 1
fi
mkdir -p build/vivado
vivado -mode batch -source scripts/vivado_timing.tcl \
    -log build/vivado/vivado.log -journal build/vivado/vivado.jou \
    -tclargs "${1:-20.0}"
