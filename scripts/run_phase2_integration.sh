#!/bin/bash
# =============================================================================
# run_phase2_integration.sh — Phase 2 Integration Test Runner
#
# Author : Ankit
# Phase  : 2 — Complete Processor Integration and Top-Level Design
#
# Compiles the full RV32I processor and runs the integration testbench
# using Icarus Verilog. Generates a VCD waveform in build/.
# =============================================================================

set -e

PROJ_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJ_DIR/build"

echo ""
echo "============================================================="
echo " Phase 2: RV32I Integration Test"
echo "============================================================="
echo ""

# Create build directory
mkdir -p "$BUILD_DIR"

# Change to project root (hex file paths are relative)
cd "$PROJ_DIR"

echo "[1/3] Compiling all RTL modules + integration testbench..."
iverilog -o "$BUILD_DIR/tb_rv32i_integration" \
    -I rtl \
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
    testbench/tb_rv32i_integration.v
echo "       Compilation successful."
echo ""

echo "[2/3] Running integration simulation..."
echo ""
vvp "$BUILD_DIR/tb_rv32i_integration"
echo ""

echo "[3/3] Waveform saved to: $BUILD_DIR/tb_rv32i_integration.vcd"
echo ""
echo "       To view waveform: gtkwave $BUILD_DIR/tb_rv32i_integration.vcd"
echo ""
