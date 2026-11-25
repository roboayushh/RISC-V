#!/usr/bin/env bash
# =============================================================================
# run_memory_integration.sh — Phase 2 Data Memory / LW / SW Test Runner
#
# Author : Rashmi
# Phase  : 2 — Data Memory Integration, LW/SW Execution and Memory Verification
#
# Compiles the fully integrated RV32I processor (all RTL + rv32i_core +
# rv32i_top) together with the dedicated memory-integration testbench and runs
# it in Icarus Verilog. A VCD waveform is written to build/.
# =============================================================================

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v iverilog >/dev/null 2>&1; then
    echo "ERROR: iverilog not found. Install Icarus Verilog (brew install icarus-verilog)."
    exit 1
fi

mkdir -p build

echo ""
echo "============================================================="
echo " Phase 2: Data Memory / LW / SW Integration Test (Rashmi)"
echo "============================================================="
echo ""

echo "[1/2] Compiling full processor + memory-integration testbench..."
iverilog -g2005 -o build/tb_memory_integration \
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
    rtl/rv32i_core.v \
    rtl/rv32i_top.v \
    testbench/tb_memory_integration.v
echo "      Compilation successful."
echo ""

echo "[2/2] Running simulation..."
vvp build/tb_memory_integration | tee "build/run_memory_integration.sh.log"
grep -Fq "MEMORY INTEGRATION TEST PASSED" "build/run_memory_integration.sh.log"
echo ""
echo "Waveform: $ROOT_DIR/build/tb_memory_integration.vcd"
