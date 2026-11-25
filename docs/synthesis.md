# Synthesis statistics

The tables below record the original Yosys 0.70 submission: 22,445 cells.
The corrected mixed-demo build with Yosys 0.71 has 22,531 cells, 9,545 muxes,
9,248 flip-flops, and branch-target depth 57. See synthesis_report.txt for the
current generated breakdown. Tool versions and program contents affect mapping.

Generic synthesis of the full 10-instruction core (`rv32i_core`) with Yosys.
The current generated report includes the initialized instruction ROM.
Regenerate the current build with:

```bash
./synthesize.sh
```

## Design summary

| Metric | Value |
|---|---|
| Top module | `rv32i_core` |
| Total cells (incl. submodules) | 22445 |
| Flip-flops (sequential state) | 9248 |
| Wires / wire bits | 13220 / 23666 |
| Ports / port bits | 62 / 997 |
| Clocks per instruction (CPI) | 1 (single-cycle) |

## Sequential state (flip-flops)

| Module | Flip-flops | Cell type |
|---|---|---|
| data_memory (256 x 32) | 8192 | `$_DFFE_PP_` |
| register_file (32 x 32) | 1024 | `$_DFFE_PP_` |
| program_counter (32-bit) | 32 | `$_SDFF_PP0_` |
| **Total** | **9248** | |

Note: the register file and data memory are modelled as asynchronous-read
arrays, so generic synthesis maps each storage bit to a flip-flop rather than
inferring a RAM macro. On an FPGA or ASIC flow these would map to block RAM or
a compiled memory, so 9248 is an upper bound on sequential resources, not a
silicon gate count.

## Cell usage by module (cells incl. submodules)

| Module | Cells |
|---|---|
| rv32i_core (top) | 22445 |
| data_memory | 16740 |
| register_file | 4552 |
| alu | 618 |
| branch_target | 164 |
| instruction_memory | 83 |
| control_unit | 53 |
| alu_src_mux | 32 |
| next_pc_mux | 32 |
| program_counter | 32 |
| writeback_mux | 32 |
| immediate_generator | 30 |
| alu_control | 15 |

## Cell-type breakdown (top module)

| Cell type | Count | Role |
|---|---|---|
| `$_DFFE_PP_` | 9216 | Register-file and data-memory storage bits |
| `$_SDFF_PP0_` | 32 | Program-counter bits (synchronous reset) |
| `$_MUX_` | 9543 | Read-port, ROM, writeback, operand and next-PC selection |
| `$_AND_` | 1301 | Combinational logic |
| `$_NAND_` | 1064 | Combinational logic |
| `$_NOR_` | 246 | Combinational logic |
| `$_ORNOT_` | 356 | Combinational logic |
| `$_ANDNOT_` | 120 | Combinational logic |
| `$_OR_` | 409 | Combinational logic |
| `$_XOR_` | 90 | ALU arithmetic / XOR |
| `$_XNOR_` | 49 | Combinational logic |
| `$_NOT_` | 19 | Combinational logic |
| **Total** | **22445** | |

Synthesis completes with no inferred latches; all state is in explicit,
clock-edge flip-flops. The single-cycle organisation gives a fixed CPI of 1.
The full raw table, generic logic-depth results, and generated netlist are in
[`synthesis_report.txt`](../synthesis_report.txt) and
[`netlist/rv32i_core_netlist.v`](../netlist/rv32i_core_netlist.v).

## Timing and maximum operating frequency

### Why the number needs a technology

Generic Yosys synthesis is an **area-only** mapping: it emits abstract gates
(`$_AND_`, `$_MUX_`, …) that carry no picosecond delay, so it cannot by itself
print a maximum frequency. A silicon-accurate Fmax needs either a standard-cell
library (`read_liberty …; abc -liberty …` static timing) or an FPGA
place-and-route flow (Vivado). We therefore report the **technology-independent
critical-path depth** (measured and committed in `synthesize.sh`'s report), turn
it into a transparent **Fmax estimate**, and give the exact recipe for the
authoritative vendor number.

### Critical-path logic depth (measured)

Longest combinational depth per block, in generic mapped gate levels, taken from
the committed [`synthesis_report.txt`](../synthesis_report.txt) (`ltp` after
`abc`):

| Block | Depth (levels) | Note |
|---|---:|---|
| **alu** | **69** | 32-bit ripple-carry add/sub — the bottleneck |
| branch_target | 62 | PC + B-immediate 32-bit adder (branch path only) |
| register_file | 10 | async-read 32:1 address mux |
| data_memory | 9 | async-read 256-word address mux |
| control_unit | 7 | opcode/funct → control signals |
| alu_control | 5 | ALUOp + funct → operation |
| immediate_generator | 3 | I/S/B immediate select + sign extend |
| writeback_mux / next_pc_mux | 1 | single 2:1 selection |

### Single-cycle critical path (the LW path)

In a single-cycle machine the clock period must cover the **worst** instruction,
`LW`: fetch → register read → address add → data-memory read → write-back, all in
one cycle.

```
PC(FF) → instruction_memory → register_file read → alu_src_mux
       → ALU (address add) → data_memory read → writeback_mux → register_file D (setup)
```

Summing the measured depths along that path (`alu_src_mux` is a single 2:1 mux):

| Stage | Levels |
|---|---:|
| register_file read | 10 |
| alu_src_mux | 1 |
| **ALU add** | **69** |
| data_memory read | 9 |
| writeback_mux | 1 |
| **Datapath critical path** | **≈ 90** |

`control_unit` (7) runs in parallel with register read and is off the critical
path; `instruction_memory` read adds the fetch stage ahead of it. The 32-bit
ripple-carry adder is ≈ 77 % of the path — the one block worth optimizing
(carry-lookahead / carry-select would shorten it directly).

### Fmax estimate

With no cell library on hand, Fmax is estimated as `1 / (depth × t_level)` for a
representative per-level delay `t_level` (a 2-input gate plus local routing in a
mature sub-micron standard-cell process is ≈ 0.08–0.16 ns):

| t_level | Critical path (90 levels) | Estimated Fmax |
|---:|---:|---:|
| 0.08 ns | 7.2 ns | ≈ 140 MHz |
| 0.12 ns | 10.8 ns | ≈ 93 MHz |
| 0.16 ns | 14.4 ns | ≈ 69 MHz |

**Illustrative range: ≈ 70–140 MHz under the stated delay assumptions.**
This is not measured Fmax and does not predict any particular FPGA or ASIC.
The block-depth sum omits instruction-ROM delay, clock-to-Q, setup, routing,
and fanout; independently mapped maxima need not form one realizable path.

### Authoritative Fmax (Vivado flow)

For a vendor-accurate number, run the suggested FPGA flow and read the timing
report. Set a target clock, implement, and inspect the worst negative slack
(WNS); achievable Fmax = `1 / (T_target − WNS)`:

```tcl
# Vivado (e.g. Artix-7 xc7a35t). rv32i_top is the synthesis top.
read_verilog [glob rtl/*.v]
synth_design -top rv32i_top -part xc7a35tcpg236-1
create_clock -name clk -period 20.000 [get_ports clk]   ;# 50 MHz target
opt_design; place_design; route_design
report_timing_summary -file build/logs/vivado_timing.rpt
# Fmax = 1 / (20 ns - WNS)
```

See [comparison.md](comparison.md) for how CPI, clock period and Fmax trade off
against multi-cycle and pipelined baselines.
