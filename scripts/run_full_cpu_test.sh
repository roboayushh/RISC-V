#!/usr/bin/env bash
set -euo pipefail

# Compile and run the full single-cycle RV32I CPU integration test.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v iverilog >/dev/null 2>&1; then
    echo "ERROR: iverilog not found. Install Icarus Verilog (brew install icarus-verilog)."
    exit 1
fi

mkdir -p build

echo "============================================================"
echo "Full RV32I CPU integration test (arithmetic, memory and branches)"
echo "============================================================"

iverilog -g2005 -o build/tb_rv32i_core_full \
    rtl/program_counter.v \
    rtl/instruction_memory.v \
    rtl/control_unit.v \
    rtl/register_file.v \
    rtl/immediate_generator.v \
    rtl/alu_src_mux.v \
    rtl/alu_control.v \
    rtl/alu.v \
    rtl/data_memory.v \
    rtl/writeback_mux.v \
    rtl/branch_target.v \
    rtl/next_pc_mux.v \
    rtl/rv32i_core_full.v \
    testbench/tb_rv32i_core_full.v

output="$(vvp build/tb_rv32i_core_full 2>&1)"
printf '%s\n' "$output"

if [[ "$output" != *"FULL RV32I CPU TEST PASSED"* ]]; then
    echo "ERROR: full CPU test did not report PASS."
    exit 1
fi

echo
echo "============================================================"
echo "FULL CPU TEST PASSED"
echo "Waveform: ${ROOT_DIR}/build/tb_rv32i_core_full.vcd"
echo "============================================================"
