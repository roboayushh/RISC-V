#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

for tool in iverilog vvp; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "ERROR: $tool is missing. On macOS: brew install icarus-verilog" >&2
        exit 1
    fi
done

mkdir -p build

iverilog -g2005 -s tb_alu -o build/tb_alu rtl/alu.v testbench/tb_alu.v
vvp build/tb_alu

iverilog -g2005 -s tb_alu_control -o build/tb_alu_control \
    rtl/alu_control.v testbench/tb_alu_control.v
vvp build/tb_alu_control

echo "ALL ALU TESTS PASSED"
