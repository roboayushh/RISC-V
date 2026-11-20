#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

for tool in verilator yosys; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'Error: %s is missing.\n' "$tool" >&2
        exit 1
    fi
done

for source in rtl/*.v; do
    top=${source##*/}
    top=${top%.v}
    verilator --lint-only -Wall --top-module "$top" rtl/*.v
    yosys -Q -q -p "read_verilog rtl/*.v; synth -top $top; select -assert-none t:\$_DLATCH_*; check -assert"
    printf '%s passed lint and synthesis checks\n' "$top"
done
