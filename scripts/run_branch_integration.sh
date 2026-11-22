#!/usr/bin/env bash
set -euo pipefail

# M13 runner for Saumya's branch and assembly work package.
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
for tool in iverilog vvp; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'ERROR: %s is required. Install Icarus Verilog.\n' "$tool" >&2
        exit 1
    fi
done

mkdir -p build/branch
programs=(arithmetic memory branch_equal branch_not_equal integration branch_offsets)
rtl_sources=(
    rtl/program_counter.v rtl/instruction_memory.v rtl/control_unit.v
    rtl/register_file.v rtl/immediate_generator.v rtl/alu_src_mux.v
    rtl/alu_control.v rtl/alu.v rtl/data_memory.v rtl/writeback_mux.v
    rtl/branch_target.v rtl/next_pc_mux.v rtl/rv32i_core.v rtl/rv32i_top.v
)

for program_id in "${!programs[@]}"; do
    program="${programs[$program_id]}"
    executable="build/branch/$program"
    iverilog -g2005 -Wall -s tb_branch_integration \
        -P "tb_branch_integration.PROGRAM_ID=$program_id" \
        -o "$executable" "${rtl_sources[@]}" testbench/tb_branch_integration.v
    vvp "$executable" | tee "build/branch/$program.log"
    if ! grep -Fq "BRANCH PROGRAM PASSED: $program (" "build/branch/$program.log"; then
        printf 'ERROR: %s did not report completion.\n' "$program" >&2
        exit 1
    fi
done
printf 'BRANCH INTEGRATION TEST PASSED (6 assembly programs)\n'
printf 'Logs, CSV execution traces and VCD waveforms: %s/build/branch/\n' "$repo_root"
