# Final processor verification

**Result on 23 November 2026 — 11 simulation suites passed, 0 failed.** Saumya ran the final regression on the integrated Verilog RTL from revision `7f584f7`, with the M14 test additions in this submission. Icarus Verilog 13.0 compiled the benches and VVP executed them. The tests exercise the ten instructions in the project subset. Coverage is directed.

## Reproduce the run

From the repository root, run `./run_tests.sh` with Bash, Icarus Verilog and VVP on PATH. Each suite writes its own log under `build/regression/`. The runner checks the process status, rejects explicit failure messages, and requires completion markers. It continues after a failed suite and returns nonzero if any suite fails. Fresh waveforms are written under `build/` and `build/branch/`.

The [submission evidence archive](verification_evidence.zip) contains the run summary, 11 suite logs, VCD waveforms, and six per-program logs and CSV traces. Paths inside the archive are relative to the build directory.

## Regression results

| Suite log | Observed result | Behavior exercised |
|---|---|---|
| fetch | Three benches passed | PC reset and update, instruction ROM, integrated fetch |
| storage | Both benches passed | Register reads/writes, x0, data RAM enables and bounds |
| mux_immediate | Five benches passed | Immediate generation (17 cases), ALU source (10), writeback (10), next PC (11), branch target (18) |
| alu | Two benches passed | 17 ALU cases and 14 ALU-control cases |
| phase1 | Three benches passed | Decoder (20 cases), arithmetic core and one-word memory boundaries |
| full_cpu | Passed | Earlier complete-core regression retained for compatibility |
| integration | 20 checks passed | All ten supported instructions, both branch outcomes, register and RAM results |
| memory | 34 checks passed | Loads, stores, offsets, read after write, multiple locations and skipped memory operations |
| alu_integration | 63 checks passed | ALU controls/results, wraparound, signed limits, addresses and branch comparison |
| branch | Six assembly programs passed | All ten instructions in the mixed program, forward/backward offsets and exact PC routes |
| final_cpu | 23 retirements passed | Cycle-by-cycle architectural state, unsupported instructions, recovery and x0 protection |

## Processor-level acceptance checks

The [annotated machine-code image](../programs/final_verification.hex) runs on the Phase 2 core. The [final bench](../testbench/tb_final_verification.v) supplies a 10 ns clock, holds synchronous reset for two rising edges, and releases it on a falling edge. It compares the committed PC, all 32 registers, and every word in its 32-word RAM with an independent expected state after each instruction. It uses four-state comparisons so an unknown value fails the test.

| Stimulus | Expected and observed behavior |
|---|---|
| ADDI, SW, LW | x1 becomes 64. Storing -7 updates word 16. The following load writes -7 to x3. |
| ADD, SUB, AND, OR, XOR | Results in x4 through x8 are -14, 0, -7, 64, 0 respectively. |
| Conditional control flow | BEQ skips a store to byte address 68. BNE first falls through, then skips a write of 99 to x9. |
| Unsupported MUL, SLL, ORI, LB, SB, BLT and unknown opcode | At PCs 0x3c through 0x54 each advances PC by four. Register write, memory read/write and branch selection are low. Every register and RAM word retains its previous value. |
| Legal operation after unsupported words | LW at 0x58 reloads -7 into x10. Writing 5 to x0 leaves x0 zero. The terminal self-branch keeps PC at 0x60. |

**Failure-path check.** In a disposable copy, the ADDI decoder was changed to accept ORI. The final bench stopped at PC 0x44 on instruction 0x0010e493, the decoder suite also failed, and the runner returned nonzero with nine suites passing and two failing.
