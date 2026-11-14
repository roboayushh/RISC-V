#!/usr/bin/env bash
set -euo pipefail

# Run from this package's root so VCD output lands in build/.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v iverilog >/dev/null 2>&1; then
    echo "ERROR: iverilog was not found. Install Icarus Verilog first (brew install icarus-verilog)."
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
    "Register File test" \
    "build/tb_register_file" \
    "REGISTER FILE TEST PASSED" \
    rtl/register_file.v \
    testbench/tb_register_file.v

run_test \
    "Data Memory test" \
    "build/tb_data_memory" \
    "DATA MEMORY TEST PASSED" \
    rtl/data_memory.v \
    testbench/tb_data_memory.v

echo
echo "============================================================"
echo "ALL STORAGE-MODULE TESTS PASSED"
echo "Waveform files are in: ${ROOT_DIR}/build/"
echo "============================================================"
