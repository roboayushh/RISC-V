#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
mkdir -p build

for tool in iverilog vvp; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'ERROR: %s is required.\n' "$tool" >&2
        exit 1
    fi
done

iverilog -g2005 -o build/tb_alu_integration \
    rtl/program_counter.v rtl/instruction_memory.v rtl/control_unit.v \
    rtl/register_file.v rtl/immediate_generator.v rtl/alu_src_mux.v \
    rtl/alu_control.v rtl/alu.v rtl/data_memory.v rtl/writeback_mux.v \
    rtl/branch_target.v rtl/next_pc_mux.v rtl/rv32i_core.v rtl/rv32i_top.v \
    testbench/tb_alu_integration.v

vvp build/tb_alu_integration
printf '\nWaveform: %s/build/tb_alu_integration.vcd\n' "$ROOT_DIR"
