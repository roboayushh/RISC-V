# Phase 1 architecture

The runnable prototype is [rv32i_phase1_core](../rtl/rv32i_phase1_core.v). It
uses [rv32i_core](../rtl/rv32i_core.v) as the instruction-fetch stage. The
fetch stage has its own tests for the program counter and instruction memory.
The integrated prototype adds decode, execution and register writeback.

![Phase 1 arithmetic datapath and Phase 2 connections](figures/phase1-datapath.svg)

Solid blocks and connections show the working arithmetic path. Dashed blocks
show where memory writeback and branch selection enter the design in Phase 2.

1. The rising clock edge updates the 32-bit, byte-addressed PC. Active-high
   synchronous reset selects address zero. Normal operation selects PC + 4.
2. Instruction memory returns a 32-bit word using an asynchronous read.
   Misaligned and out-of-range fetches return the canonical NOP, `00000013`.
3. The instruction selects two register operands and a destination. The control
   unit validates the opcode and function fields. The immediate generator
   sign-extends I-, S- or B-type immediates and the ALU operand mux selects
   the second register operand or the immediate.
4. The ALU computes the result combinationally. The destination updates on the
   rising edge when reset is low, `RegWrite` is high and `ResultSrc` selects
   the ALU. Register x0 always reads zero and discards writes.

## Integration status

| Block | Phase 1 status |
|---|---|
| Program counter and instruction memory | Integrated and tested |
| Main control, register file, immediate generator, ALU source mux, ALU decoder and ALU | Integrated for the six arithmetic instructions |
| Data memory and writeback mux | Implemented and individually tested. Wire them into the core in Phase 2 |
| Branch target and next-PC mux | Implemented and individually tested. Connect the branch condition and PC selection in Phase 2 |

The prototype loads the 14-word demo image. The fetch scaffold and data memory
default to 256 words. The one-word memory regression verifies the minimum
supported depth with valid, misaligned and out-of-range addresses.

See the [control truth table and waveform guide](control_phase1_guide.md) for
the decoder outputs, simulation commands and expected results.

## Full 10-instruction datapath

[rv32i_core_full](../rtl/rv32i_core_full.v) wires every block together,
including data memory, the writeback mux, the branch target adder and the
next-PC mux, and runs the complete 10-instruction subset (ADD, SUB, AND, OR,
XOR, ADDI, LW, SW, BEQ, BNE). The waveform below is the self-checking
`tb_rv32i_core_full` run (`build/tb_rv32i_core_full.vcd`).

![Full RV32I single-cycle CPU waveform, all 10 instructions](figures/full-cpu-waveform.png)

Reading the trace:

- `reset` holds the PC at zero, then `pc` advances by four each cycle.
- The first write-back value `write_data = 0000000a` is `x1 = 10` from `ADDI`.
- The single `MemWrite` pulse is the `SW` storing `30` to `mem[0]`.
- The two `PCSrc` pulses are the taken `BEQ` (`x3 == x4`) and `BNE`
  (`x1 != x2`); each skips the following `ADDI`, so `x5` and `x7` stay zero.
- Execution ends on the `00000013` NOP padding.

The final architectural state (`x1=10, x2=20, x3=30, x4=30, x5=0, x6=7,
x7=0, x8=5, mem[0]=30`) is asserted by the testbench, so the waveform is a
visual confirmation of a run that already passes every check.

Running `bash scripts/run_full_cpu_test.sh` prints each self-checked result
and the final `FULL RV32I CPU TEST PASSED` banner:

![Full CPU integration test passing all register and memory checks](figures/full-cpu-test-pass.png)

Generic Yosys synthesis of this core reports 22374 cells and 9248 flip-flops
with no inferred latches. See [synthesis statistics](synthesis.md) for the full
per-module and cell-type tables.
