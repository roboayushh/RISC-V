#!/usr/bin/env bash
# =============================================================================
# run_saumya_tests.sh
#
# Compiles and simulates all five modules assigned to Saumya:
#   1. Immediate Generator
#   2. ALU Source MUX
#   3. Write-Back MUX
#   4. Next-PC MUX
#   5. Branch Target Calculator
#
# Usage (from the repository root):
#   bash scripts/run_saumya_tests.sh
#
# Outputs:
#   build/tb_immediate_generator  - compiled simulation executable
#   build/tb_alu_src_mux          - compiled simulation executable
#   build/tb_writeback_mux        - compiled simulation executable
#   build/tb_next_pc_mux          - compiled simulation executable
#   build/tb_branch_target        - compiled simulation executable
#   build/tb_immediate_generator.vcd
#   build/tb_alu_src_mux.vcd
#   build/tb_writeback_mux.vcd
#   build/tb_next_pc_mux.vcd
#   build/tb_branch_target.vcd
#
# Exit codes:
#   0 - all tests passed
#   1 - one or more tests failed or tools missing
#
# Author : Saumya
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Resolve repository root (works regardless of which directory the script is
# called from, as long as the script lives under scripts/).
# ---------------------------------------------------------------------------
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# ---------------------------------------------------------------------------
# 1. Check that the required simulation tools are available.
# ---------------------------------------------------------------------------
for tool in iverilog vvp; do
    if ! command -v "$tool" > /dev/null 2>&1; then
        echo "ERROR: '$tool' was not found in PATH."
        echo "       Install Icarus Verilog first:"
        echo "       macOS (Homebrew): brew install icarus-verilog"
        exit 1
    fi
done

echo "============================================================"
echo " Icarus Verilog: $(iverilog -V 2>&1 | head -1)"
echo "============================================================"

# ---------------------------------------------------------------------------
# 2. Create build directory for simulation outputs and VCD waveforms.
# ---------------------------------------------------------------------------
mkdir -p build

# ---------------------------------------------------------------------------
# 3. Test runner function.
#
# Arguments:
#   $1 label          - Human-readable test name printed to the terminal.
#   $2 output_file    - Path to the compiled simulation binary (in build/).
#   $3 pass_marker    - Substring that must appear in simulation output for PASS.
#   $4+ source files  - All RTL and testbench Verilog source files to compile.
#
# Behavior:
#   - Compiles the sources with iverilog (-g2005 for Verilog-2005 compatibility).
#   - Runs the compiled simulation with vvp.
#   - Checks that the PASS marker appears in the simulation output.
#   - Prints PASS/FAIL and exits non-zero on the first failure.
# ---------------------------------------------------------------------------
run_test() {
    local label="$1"
    local output_file="$2"
    local pass_marker="$3"
    shift 3

    echo
    echo "============================================================"
    echo "  TEST: ${label}"
    echo "============================================================"

    # Compile.  -g2005 matches the convention used by all existing test scripts.
    if ! iverilog -g2005 -s "$(basename "$output_file")" -o "$output_file" "$@"; then
        echo "ERROR: Compilation failed for ${label}."
        exit 1
    fi

    # Simulate and capture output (stdout + stderr together).
    local sim_output
    sim_output="$(vvp "$output_file" 2>&1)"
    printf '%s\n' "$sim_output"

    # Check for the expected PASS marker.
    if [[ "$sim_output" != *"$pass_marker"* ]]; then
        echo
        echo "ERROR: ${label} did not print the expected PASS marker."
        echo "       Expected to find: \"${pass_marker}\""
        exit 1
    fi

    echo "  -> ${label}: OK"
}

# ---------------------------------------------------------------------------
# 4. Run each of Saumya's five module tests.
# ---------------------------------------------------------------------------

run_test \
    "Immediate Generator" \
    "build/tb_immediate_generator" \
    "IMMEDIATE GENERATOR TEST PASSED" \
    rtl/immediate_generator.v \
    testbench/tb_immediate_generator.v

run_test \
    "ALU Source MUX" \
    "build/tb_alu_src_mux" \
    "ALU SRC MUX TEST PASSED" \
    rtl/alu_src_mux.v \
    testbench/tb_alu_src_mux.v

run_test \
    "Write-Back MUX" \
    "build/tb_writeback_mux" \
    "WRITE-BACK MUX TEST PASSED" \
    rtl/writeback_mux.v \
    testbench/tb_writeback_mux.v

run_test \
    "Next-PC MUX" \
    "build/tb_next_pc_mux" \
    "NEXT PC MUX TEST PASSED" \
    rtl/next_pc_mux.v \
    testbench/tb_next_pc_mux.v

run_test \
    "Branch Target Calculator" \
    "build/tb_branch_target" \
    "BRANCH TARGET TEST PASSED" \
    rtl/branch_target.v \
    testbench/tb_branch_target.v

# ---------------------------------------------------------------------------
# 5. Final summary.
# ---------------------------------------------------------------------------
echo
echo "============================================================"
echo "  ALL SAUMYA MODULE TESTS PASSED"
echo "  Waveform files:"
echo "    build/tb_immediate_generator.vcd"
echo "    build/tb_alu_src_mux.vcd"
echo "    build/tb_writeback_mux.vcd"
echo "    build/tb_next_pc_mux.vcd"
echo "    build/tb_branch_target.vcd"
echo "============================================================"
