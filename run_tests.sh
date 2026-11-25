#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build/regression
passed=0
failed=0

# Some original benches call $finish on a mismatch. Require their PASS
# markers as well as a successful command, and reject explicit failure lines.
run_suite() {
    local name="$1" markers="$2" log="build/regression/$1.log" marker
    shift 2
    if "$@" >"$log" 2>&1 && ! grep -Eq '(^|[[:space:]])(FAIL|FAILED|FATAL|ERROR)([[:space:]:]|$)' "$log"; then
        local complete=true
        while IFS= read -r marker; do
            if ! grep -Fq "$marker" "$log"; then
                complete=false
                break
            fi
        done <<< "$markers"
        if [[ "$complete" == true ]]; then
            printf 'PASS  %s\n' "$name"
            passed=$((passed + 1))
            return
        fi
    fi
    printf 'FAIL  %s  (see %s)\n' "$name" "$log"
    tail -n 40 "$log"
    failed=$((failed + 1))
}

final_cpu() {
    iverilog -g2005 -Wall -s tb_final_verification -o build/tb_final_verification \
        rtl/*.v testbench/tb_final_verification.v && vvp build/tb_final_verification
}

run_suite fetch 'ALL THREE TESTS PASSED' bash scripts/run_fetch_tests.sh
run_suite storage 'ALL STORAGE-MODULE TESTS PASSED' bash scripts/run_storage_tests.sh
run_suite mux_immediate 'ALL SAUMYA MODULE TESTS PASSED' bash scripts/run_saumya_tests.sh
run_suite alu $'ALU TEST PASSED\nALU CONTROL TEST PASSED' bash scripts/run_alu_tests.sh
run_suite phase1 $'CONTROL UNIT TEST PASSED\nPHASE 1 ARITHMETIC TEST PASSED\nONE-WORD MEMORY TEST PASSED' bash scripts/run_phase1_tests.sh
run_suite full_cpu 'FULL RV32I CPU TEST PASSED' bash scripts/run_full_cpu_test.sh
run_suite integration 'PHASE 2 INTEGRATION TEST PASSED' bash scripts/run_phase2_integration.sh
run_suite memory 'MEMORY INTEGRATION TEST PASSED' bash scripts/run_memory_integration.sh
run_suite alu_integration 'ALU INTEGRATION TEST PASSED' bash scripts/run_alu_integration.sh
run_suite branch 'BRANCH INTEGRATION TEST PASSED' bash scripts/run_branch_integration.sh
run_suite final_cpu 'FINAL PROCESSOR TEST PASSED' final_cpu
printf '%s suites passed, %s failed\n' "$passed" "$failed"
[[ "$failed" -eq 0 ]]
