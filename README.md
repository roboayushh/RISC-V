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
| Ayush | Execution | ALU, ALU control (planned) |
| Saumya | Operand selection and immediates | Multiplexers, immediate generator (planned) |
| Samiksha | Control | Control unit (planned) |

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
│   └── data_memory.v
├── testbench/                Self-checking Verilog testbenches
│   ├── tb_program_counter.v
│   ├── tb_instruction_memory.v
│   ├── tb_rv32i_core.v
│   ├── tb_register_file.v
│   └── tb_data_memory.v
├── scripts/                  Build and simulation scripts
│   ├── run_fetch_tests.sh
│   └── run_storage_tests.sh
├── programs/                 Machine-code test images
│   └── test_program.hex
└── docs/                     Documentation
    ├── architecture.md       Datapath architecture and diagrams
    ├── fetch_path_guide.md   Setup and run guide (fetch path)
    ├── storage_guide.md      Setup and run guide (storage modules)
    └── storage_modules.md    Register file and data memory interface reference
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
```

Each script compiles the relevant modules, runs the self-checking testbenches, and
fails if any testbench does not print its PASS marker.

### Lint (Verilator)

```bash
verilator --lint-only -Wall rtl/program_counter.v
verilator --lint-only -Wall rtl/instruction_memory.v
verilator --lint-only -Wall rtl/register_file.v
verilator --lint-only -Wall rtl/data_memory.v
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
[`docs/storage_guide.md`](docs/storage_guide.md).

---

## 6. Phase 1 status

Phase 1 delivers the individual processor building blocks, each with its own
self-checking testbench, verified before any CPU integration. The two completed
contributions below are implemented, simulated, linted clean under Verilator `-Wall`,
and synthesized under Yosys with no inferred latches.

### Completed

| Module | Owner | Simulation | Lint | Synthesis |
|---|---|---|---|---|
| `program_counter.v` | Ankit | Pass | Clean | 30 flip-flops, no latches |
| `instruction_memory.v` | Ankit | Pass | Clean | ROM/combinational read |
| `rv32i_core.v` (fetch scaffold) | Ankit | Pass | Clean | No latches |
| `register_file.v` | Rashmi | Pass (12 cases) | Clean | 1024 flip-flops (32x32) |
| `data_memory.v` | Rashmi | Pass (15 cases) | Clean | 8192 flip-flops (256x32) |

Verification highlights:
- Program Counter: reset to 0x0, sequential +4 progression, external next-PC load.
- Instruction Memory: `$readmemh` load, byte-to-word addressing, misaligned and
  out-of-range accesses return NOP, empty-init behavior.
- Register File: x0 always reads zero and ignores writes, independent dual
  asynchronous reads, synchronous write with `RegWrite`, pre/post clock-edge behavior.
- Data Memory: byte-to-word address conversion, separate read/write enables,
  misaligned and out-of-range accesses handled deterministically, data persistence.

### Remaining for Phase 1

| Component | Owner | Status |
|---|---|---|
| ALU and ALU control | Ayush | Planned |
| Immediate generator and multiplexers | Saumya | Planned |
| Control unit | Samiksha | Planned |

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

---

## 7. Forward plan (Phase 2 and beyond)

The milestones below follow the project roadmap. Phase 1 corresponds to module
development and unit verification; Phase 2 covers integration, full-processor
verification, and hardware analysis.

### Integration and execution
1. Complete the remaining Phase 1 modules (ALU, ALU control, immediate generator,
   multiplexers, control unit) with their own self-checking testbenches.
2. Integrate the arithmetic datapath into `rv32i_core.v`, replacing the Phase 1
   fetch scaffold's fixed PC+4 with next-PC selection.
3. Add memory access and branch execution so all ten instructions run end to end.

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
