#!/usr/bin/env bash
set -euo pipefail

# Keep the program image and waveform paths relative to the repository root.
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for tool in iverilog vvp; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'Error: %s is missing. Install Icarus Verilog (brew install icarus-verilog).\n' "$tool" >&2
        exit 1
    fi
done

mkdir -p build

run_test() {
    local top="$1"
    shift
    local executable="build/$top"

    iverilog -g2005 -Wall -s "$top" -o "$executable" "$@" "testbench/$top.v"
    vvp "$executable"
}

run_test tb_control_unit \
    rtl/control_unit.v rtl/alu_control.v rtl/immediate_generator.v

run_test tb_rv32i_phase1_core \
    rtl/program_counter.v rtl/instruction_memory.v rtl/rv32i_core.v \
    rtl/control_unit.v rtl/alu_control.v rtl/immediate_generator.v \
    rtl/alu_src_mux.v rtl/register_file.v rtl/alu.v rtl/rv32i_phase1_core.v

printf 'PHASE 1 TESTS PASSED\n'
printf 'Waveforms: %s/build/tb_control_unit.vcd and %s/build/tb_rv32i_phase1_core.vcd\n' \
    "$repo_root" "$repo_root"
