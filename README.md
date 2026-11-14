# Single-Cycle RISC-V RV32I Processor

A modular, single-cycle RISC-V processor implementing a subset of the RV32I base
integer instruction set, written in synthesizable Verilog-2005. This is an academic
group project for the Modern Computer Architecture course (B.Tech CS and AI).

The goal is not merely to make a processor execute instructions, but to build a
modular, independently verifiable CPU that demonstrates how instruction fetch,
decoding, control, arithmetic, memory access, and program flow work together at the
hardware level, with evidence from simulation, linting, and synthesis.

---

## 1. Project scope

| Decision | Choice |
|---|---|
| Architecture | RISC-V RV32I subset |
| Processor type | Single-cycle, non-pipelined |
| HDL | Verilog-2005 RTL |
| Datapath width | 32 bits |
| Registers | 32 general-purpose, 32 bits each (x0 hardwired to zero) |
| Instruction memory | 256 x 32-bit words (configurable) |
| Data memory | 256 x 32-bit words (1 KiB) |
| Reset PC | 0x00000000 |
| Memory reads | Asynchronous (preserves true single-cycle execution) |
| Simulation | Icarus Verilog |
| Linting | Verilator |
| Synthesis | Yosys |
| Waveforms | Surfer / VaporView |
| Host platform | macOS (Apple Silicon) |

This is an RV32I subset for education, not a complete RV32I implementation. We do not
claim full ISA coverage, exception handling, or FPGA timing closure.

### Supported instructions

Ten instructions covering arithmetic, logic, memory, and control flow:

| Instruction | Type | Operation |
|---|---|---|
| ADD | R | Register addition |
| SUB | R | Register subtraction |
| AND | R | Bitwise AND |
| OR  | R | Bitwise OR |
| XOR | R | Bitwise XOR |
| ADDI | I | Register + signed immediate |
| LW | I | Load 32-bit word |
| SW | S | Store 32-bit word |
| BEQ | B | Branch if equal |
| BNE | B | Branch if not equal |

---

## 2. Team and contributions

| Member | Responsibility | Modules |
|---|---|---|
| Ankit | Instruction-fetch path and initial integration | `program_counter.v`, `instruction_memory.v`, `rv32i_core.v` (fetch scaffold) |
| Rashmi | Storage components | `register_file.v`, `data_memory.v` |
| Ayush | Execution | `alu.v`, `alu_control.v` (standalone Phase 1 modules) |
| Saumya | Operand selection and immediates | Multiplexers, immediate generator (planned) |
| Samiksha | Control and arithmetic verification | `control_unit.v`, `rv32i_phase1_core.v` |

A per-file ownership map is maintained in Section 6.

---

## 3. Repository structure

```text
RISC-V/
├── README.md                 Project overview (this file)
├── rtl/                      Synthesizable Verilog design modules
│   ├── program_counter.v
│   ├── instruction_memory.v
│   ├── rv32i_core.v
│   ├── register_file.v
│   ├── data_memory.v
│   ├── alu.v
│   └── alu_control.v
├── testbench/                Self-checking Verilog testbenches
│   ├── tb_program_counter.v
│   ├── tb_instruction_memory.v
│   ├── tb_rv32i_core.v
│   ├── tb_register_file.v
│   ├── tb_data_memory.v
│   ├── tb_alu.v
│   └── tb_alu_control.v
├── scripts/                  Build and simulation scripts
│   ├── run_fetch_tests.sh
│   ├── run_storage_tests.sh
│   └── run_alu_tests.sh
├── programs/                 Machine-code test images
│   └── test_program.hex
└── docs/                     Documentation
    ├── architecture.md       Datapath architecture and diagrams
    ├── fetch_path_guide.md   Setup and run guide (fetch path)
    ├── storage_guide.md      Setup and run guide (storage modules)
    ├── storage_modules.md    Register file and data memory interface reference
    └── alu_guide.md          ALU interface and test guide
```

The `build/` directory holds generated simulation binaries and waveforms. It is
created automatically when tests run and is ignored by Git.

---

## 4. Tools and setup

Developed and verified on macOS (Apple Silicon) using tools installable via Homebrew:

```bash
brew install icarus-verilog verilator yosys surfer
```

| Tool | Purpose |
|---|---|
| Icarus Verilog (`iverilog`, `vvp`) | Compilation and simulation |
| Verilator | RTL linting |
| Yosys | Logic synthesis and resource analysis |
| Surfer / VaporView | Waveform inspection |

---

## 5. Building and running

All commands are run from the repository root.

### Run the test suites

```bash
bash scripts/run_fetch_tests.sh      # PC, instruction memory, fetch integration
bash scripts/run_storage_tests.sh    # register file, data memory
bash scripts/run_alu_tests.sh        # ALU and ALU control
bash scripts/run_phase1_tests.sh     # main decoder and arithmetic processor demo
```

The scripts compile the relevant modules and run the self-checking testbenches.
See the [Phase 1 control and arithmetic guide](docs/control_phase1_guide.md)
for the decoder truth table, simulation results, and waveform.

### Lint (Verilator)

```bash
verilator --lint-only -Wall rtl/program_counter.v
verilator --lint-only -Wall rtl/instruction_memory.v
verilator --lint-only -Wall rtl/register_file.v
verilator --lint-only -Wall rtl/data_memory.v
verilator --lint-only -Wall rtl/alu.v
verilator --lint-only -Wall rtl/alu_control.v
```

### Synthesis checks (Yosys)

```bash
yosys -p "read_verilog rtl/register_file.v; synth -top register_file; stat"
yosys -p "read_verilog rtl/data_memory.v;  synth -top data_memory;  stat"
```

### View waveforms

```bash
surfer build/tb_register_file.vcd
```

For detailed, step-by-step setup instructions, see
[`docs/fetch_path_guide.md`](docs/fetch_path_guide.md) and
[`docs/storage_guide.md`](docs/storage_guide.md), and
[`docs/alu_guide.md`](docs/alu_guide.md).

---

## 6. Phase 1 status

Phase 1 delivers individually verified RTL modules and a prototype that runs
six arithmetic and logic instructions. The verification table records the
checks run for each module.

### Completed

| Module | Owner | Simulation | Lint | Synthesis |
|---|---|---|---|---|
| `program_counter.v` | Ankit | Pass | Clean | 30 flip-flops, no latches |
| `instruction_memory.v` | Ankit | Pass | Clean | ROM/combinational read |
| `rv32i_core.v` (fetch scaffold) | Ankit | Pass | Clean | No latches |
| `register_file.v` | Rashmi | Pass (12 cases) | Clean | 1024 flip-flops (32x32) |
| `data_memory.v` | Rashmi | Pass (15 cases) | Clean | 8192 flip-flops (256x32) |
| `alu.v` | Ayush | Pass (17 cases) | Clean | Combinational logic |
| `alu_control.v` | Ayush | Pass (14 cases) | Clean | Combinational logic |
| `control_unit.v` | Samiksha | Pass (20 cases) | Clean | Combinational logic |
| `rv32i_phase1_core.v` | Samiksha | Pass (14 instruction steps) | Unused input bits in immediate generator | Synthesis and structural check passed |

Verification highlights:
- Program Counter: reset to 0x0, sequential +4 progression, external next-PC load.
- Instruction Memory: `$readmemh` load, byte-to-word addressing, misaligned and
  out-of-range accesses return NOP, empty-init behavior.
- Register File: x0 always reads zero and ignores writes, independent dual
  asynchronous reads, synchronous write with `RegWrite`, pre/post clock-edge behavior.
- Data Memory: byte-to-word address conversion, separate read/write enables,
  misaligned and out-of-range accesses handled deterministically, data persistence.
- ALU: all five operations, positive/negative operands, 32-bit wraparound and zero flag.
- ALU control: ADD, SUB, AND, OR, XOR decode and unsupported-code behavior.

The immediate generator and multiplexers are documented in
[Saumya’s module guide](docs/saumya_modules.md).

Phase 1 also includes the Phase 1 deliverables required by the course: an IEEE-format
report, a prototype demonstration video (maximum five minutes), and this Git
repository with version history reflecting each member's contributions.

### Per-file ownership map

| File | Owner |
|---|---|
| `rtl/program_counter.v` | Ankit |
| `rtl/instruction_memory.v` | Ankit |
| `rtl/rv32i_core.v` | Ankit |
| `testbench/tb_program_counter.v` | Ankit |
| `testbench/tb_instruction_memory.v` | Ankit |
| `testbench/tb_rv32i_core.v` | Ankit |
| `scripts/run_fetch_tests.sh` | Ankit |
| `programs/test_program.hex` | Ankit |
| `docs/architecture.md`, `docs/fetch_path_guide.md` | Ankit |
| `rtl/register_file.v` | Rashmi |
| `rtl/data_memory.v` | Rashmi |
| `testbench/tb_register_file.v` | Rashmi |
| `testbench/tb_data_memory.v` | Rashmi |
| `scripts/run_storage_tests.sh` | Rashmi |
| `docs/storage_guide.md`, `docs/storage_modules.md` | Rashmi |
| `rtl/alu.v`, `rtl/alu_control.v` | Ayush |
| `testbench/tb_alu.v`, `testbench/tb_alu_control.v` | Ayush |
| `scripts/run_alu_tests.sh`, `docs/alu_guide.md` | Ayush |
| `rtl/immediate_generator.v`, `rtl/alu_src_mux.v`, `rtl/writeback_mux.v`, `rtl/next_pc_mux.v`, `rtl/branch_target.v` | Saumya |
| `testbench/tb_immediate_generator.v`, `testbench/tb_alu_src_mux.v`, `testbench/tb_writeback_mux.v`, `testbench/tb_next_pc_mux.v`, `testbench/tb_branch_target.v` | Saumya |
| `scripts/run_saumya_tests.sh`, `docs/saumya_modules.md` | Saumya |
| `rtl/control_unit.v`, `rtl/rv32i_phase1_core.v` | Samiksha |
| `testbench/tb_control_unit.v`, `testbench/tb_rv32i_phase1_core.v` | Samiksha |
| `programs/phase1_arithmetic.hex`, `scripts/run_phase1_tests.sh`, `docs/control_phase1_guide.md`, `docs/phase1_arithmetic_waveform.png` | Samiksha |

---

## 7. Forward plan (Phase 2 and beyond)

The milestones below follow the project roadmap. Phase 2 extends the Phase 1
arithmetic prototype with memory and branch execution, full-processor
verification, and hardware analysis.

### Integration and execution
1. Wire the data memory and select between memory and ALU writeback.
2. Wire branch comparison and select between PC+4 and the branch target.
3. Verify all ten supported instructions end to end.

### Verification
4. Build a comprehensive top-level processor testbench with architectural invariants
   (x0 stays zero, reset behavior, PC progression, enabled-only writes).
5. Write RISC-V assembly test programs assembled to machine code and compared against
   expected register and memory state.
6. Run systematic regression and functional coverage across all instruction types and
   branch outcomes, compared against a simple reference model.

### Synthesis and hardware analysis
7. Synthesize the integrated processor with Yosys and record resource utilization.
8. Analyze the critical path (expected to be the load path:
   PC to instruction memory to decode to register file to ALU to data memory to
   write-back) and discuss its effect on clock frequency.
9. Optional FPGA exploration, documenting the asynchronous-memory limitation
   (distributed RAM rather than block RAM) rather than silently changing the design.

### Delivery
10. Final technical report, clean and documented RTL, reproducible scripts, waveform
    evidence, and a complete GitHub repository.

### Key checkpoints

| Checkpoint | Condition |
|---|---|
| Core modules ready | All individual RTL modules pass unit tests |
| First functional CPU | All ten instructions execute correctly in simulation |
| Verified processor | Automated integration and regression tests pass |
| Final delivery | Complete RTL, tests, reports, and documentation |

---

## 8. Design assumptions and limitations

- RV32I subset only; unsupported instructions and misaligned accesses have documented,
  deterministic behavior and do not corrupt architectural state.
- Register x0 always reads as zero and cannot be written.
- Instructions are 32 bits wide; the PC uses byte addresses; LW and SW use
  word-aligned addresses.
- Initial memories use asynchronous reads to preserve single-cycle execution; this has
  synthesis implications on FPGAs that are documented rather than worked around.
- CPI is 1 for the supported instructions under the assumed single-cycle memory model,
  when operated at a clock period that meets timing.
