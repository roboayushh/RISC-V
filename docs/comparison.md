# Architecture comparison: single-cycle vs. multi-cycle vs. pipelined

This project implements the **single-cycle** organization. This note compares it
against the two standard alternatives for the same RV32I instruction subset, so
the design choice is explained rather than assumed. The single-cycle
column distinguishes structural properties from illustrative timing estimates; the multi-cycle and pipelined
columns are the textbook characteristics of those organizations for the same ISA
(Patterson & Hennessy; Harris & Harris).

## Summary

| Metric | **Single-cycle (this design)** | Multi-cycle | Pipelined (classic 5-stage) |
|---|---|---|---|
| CPI | **1 (fixed)** | 3–5 (varies by instruction) | ~1 ideal; >1 with stalls/flushes |
| Clock period | Long — set by the worst instruction (`LW`) | Short — set by the slowest *single* stage | Short — set by the slowest *single* stage |
| Critical path | **≈ 90 levels, illustrative block sum** (excludes fetch delay) | one stage (e.g. ALU or memory) | one stage |
| Est. Fmax (generic) | **≈ 70–140 MHz** (see [synthesis.md](synthesis.md)) | not implemented or measured | not implemented or measured |
| Throughput | Fmax × 1 IPC | 1 / (CPI × clock period); no measured ranking | up to ~1 instr/cycle at steady state |
| Control | Simple combinational decode | FSM-sequenced (micro-steps) | Combinational + hazard/forwarding logic |
| Hazards | None (no overlap) | None (no overlap) | Data, control & structural hazards |
| Register/state | PC + arch. regfile + data mem | + internal stage latches (IR, A, B, …) | + 4 pipeline registers (IF/ID … MEM/WB) |
| Datapath reuse | Each unit used once per cycle; **one** ALU, separate instruction and data memories | One ALU/memory reused across sub-steps | Separate stage resources; needs 2 memory ports (or split I/D) |
| Design effort | Lowest | Medium (FSM) | Highest (forwarding, stall, flush) |

## Why single-cycle for this project

1. **Correctness and clarity first.** With exactly one instruction in flight and
   no overlap, there are no data, control, or structural hazards to reason about.
   The datapath maps one-to-one onto the fetch–decode–execute description, which
   is the project's primary learning objective and makes waveform verification
   direct (every signal settles within the one cycle it belongs to).
2. **CPI = 1 by construction.** The performance metric is exact and needs no
   averaging over an instruction mix, unlike the multi-cycle design.
3. **Smallest control.** Control is pure combinational decode
   ([`control_unit.v`](../rtl/control_unit.v) + [`alu_control.v`](../rtl/alu_control.v));
   no microcode FSM and no hazard unit.

## The cost, quantified

The single-cycle clock must cover the **longest** path — the `LW` path through
fetch, register read, the 32-bit ALU add, the data-memory read and write-back
(an illustrative sum of ≈ 90 independently mapped levels, excluding fetch,
routing, and register timing; see
[synthesis.md](synthesis.md)). Cheaper instructions (e.g. `ADD`) finish sooner but
still wait a full period, so the clock is paced by the worst case. That is the
classic single-cycle trade-off:

- **Multi-cycle** breaks the instruction into shorter sub-steps clocked faster,
  reusing one ALU and one memory port across steps. Clock period can drop toward the
  slowest single step, but each instruction now takes 3–5 cycles (CPI > 1), and a
  control FSM plus internal latches are required.
- **Pipelining** overlaps the stages so a new instruction can issue (ideally)
  every cycle: the clock is again set by the slowest single stage, and steady-state
  throughput approaches 1 instruction/cycle when hazards and stage balance permit. The price
  is hazard handling: forwarding paths for data hazards, stalls for load-use, and
  flushes for taken branches (`BEQ`/`BNE`), plus four pipeline registers and split
  instruction/data memory access.

## Speed-up intuition

For an N-instruction program:

- Single-cycle time ≈ `N × T_long` (here `T_long` ≈ 1 / Fmax, the ~90-level path).
- Pipelined time ≈ `(N + k) × T_stage`, where `T_stage` is one stage (the ALU add
  or a memory read dominates, far shorter than `T_long`) and `k` ≈ 4 is the
  fill/drain overhead.

If `T_stage < T_long` after including pipeline overhead, a hazard-free pipeline approaches a speed-up of
roughly `T_long / T_stage` for large N — concretely, splitting off the 69-level
ALU from the ≈ 90-level single-cycle path is where most of that gain comes from.
Real speed-up is reduced by stall/flush cycles, which is exactly the complexity a
single-cycle design avoids. For this project's goals — a correct, readable,
tested ten-instruction RV32I subset — the single-cycle organization is the right baseline;
multi-cycle and pipelined designs are the natural next steps when throughput, not
clarity, becomes the objective.
