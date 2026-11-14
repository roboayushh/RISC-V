#!/usr/bin/env bash
set -euo pipefail

# Run from this script's project root so $readmemh can find programs/test_program.hex.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v iverilog >/dev/null 2>&1; then
    echo "ERROR: iverilog was not found. Install Icarus Verilog first."
    echo "macOS (Homebrew): brew install icarus-verilog"
    exit 1
fi

if ! command -v vvp >/dev/null 2>&1; then
    echo "ERROR: vvp was not found. Reinstall Icarus Verilog and check your PATH."
    exit 1
fi

mkdir -p build

run_test() {
    local label="$1"
    local output_file="$2"
    local expected_marker="$3"
    shift 3

    echo
    echo "============================================================"
    echo "Running: ${label}"
    echo "============================================================"

    iverilog -g2005 -o "$output_file" "$@"
    local simulation_output
    simulation_output="$(vvp "$output_file" 2>&1)"
    printf '%s\n' "$simulation_output"

    if [[ "$simulation_output" != *"$expected_marker"* ]]; then
        echo "ERROR: ${label} did not report the expected PASS marker."
        exit 1
    fi
}

run_test \
    "Program Counter test" \
    "build/tb_program_counter" \
    "PROGRAM COUNTER TEST PASSED" \
    rtl/program_counter.v \
    testbench/tb_program_counter.v

run_test \
    "Instruction Memory test" \
    "build/tb_instruction_memory" \
    "INSTRUCTION MEMORY TEST PASSED" \
    rtl/instruction_memory.v \
    testbench/tb_instruction_memory.v

run_test \
    "Integrated fetch-path test" \
    "build/tb_rv32i_core" \
    "RV32I FETCH-PATH TEST PASSED" \
    rtl/program_counter.v \
    rtl/instruction_memory.v \
    rtl/rv32i_core.v \
    testbench/tb_rv32i_core.v

echo
echo "============================================================"
echo "ALL THREE TESTS PASSED"
echo "Waveform files are in: ${ROOT_DIR}/build/"
echo "============================================================"
