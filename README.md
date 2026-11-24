# Single-cycle RISC-V processor

A 32-bit processor in Verilog that executes ten RV32I instructions in one clock cycle each. The final assembly workload adds **3 + 2 + 1**, stores **6** at byte address **64**, reloads it into **x4**, and branches on the result. The testbenches check the path through the processor as well as its final state.

**Project results** · 11 regression suites passed · 6 directed assembly programs · 22,445 generic cells in the synthesized core

[Final IEEE report (PDF)](docs/final_project_report.pdf) · [Editable report (LaTeX)](docs/final_project_report.tex) · [Presentation](docs/final_presentation.pptx) · [Verification report](docs/verification_report.md) · [Recorded logs, traces and waveforms](docs/verification_evidence.zip)

## Run the processor tests

From the repository root, run the following with Bash and Icarus Verilog (`iverilog` and `vvp`) on your path. On macOS with Homebrew, install the simulator with `brew install icarus-verilog`. The program images are included.

```bash
./run_tests.sh
```

A successful run ends with **`11 suites passed, 0 failed`**. Each suite writes a log under `build/regression/`. If a suite fails, the driver prints its log path, continues through the other suites, and returns a failing exit status. The reported submission run used Icarus Verilog 13.0.

| To inspect | Run or open | Evidence |
|---|---|---|
| Ten instructions on the integrated core | `bash scripts/run_phase2_integration.sh` | 20 checks of registers, memory and branch outcomes |
| Load/store behavior | `bash scripts/run_memory_integration.sh` | 34 checks covering addresses, data and writeback |
| ALU and comparisons | `bash scripts/run_alu_integration.sh` | 63 checks including signed boundaries and address arithmetic |
| Assembly execution and exact PC routes | `bash scripts/run_branch_integration.sh` | Six programs, 92 checked instruction steps, 955 checks |
| Whole-state acceptance | Run the regression and open `build/regression/final_cpu.log` | 23 steps, all 32 registers and every word of the 32-word test RAM, including seven unsupported instructions |

## Trace a program

Open [the mixed assembly program](programs/integration.S) beside `build/branch/integration.csv`. The PC is the byte address of the instruction being executed. The counter is x1, and the running sum is x2.

| At PC `0x14` | Counter | Sum | What BNE does |
|---|---:|---:|---|
| 71 ns | 2 | 3 | Returns to `0x0c` |
| 101 ns | 1 | 5 | Returns to `0x0c` |
| 131 ns | 0 | 6 | Advances to the store at `0x18` |

Open `build/branch/integration.vcd` in GTKWave or VaporView. Under `dut.u_core`, display `clk`, `pc`, `PCSrc`, `MemWrite`, `MemRead`, `alu_result`, `reg_data2` and `write_back_data`. The rising edge at **145 ns** writes six into RAM word 16. At **155 ns**, x4 captures the load result. The [branch guide](docs/phase2_branch_guide.md) gives the expected route for each program. The [waveform gallery](docs/waveforms/README.md) includes the independent store/load example using 25.

## Architecture

| Part | Design |
|---|---|
| Instruction subset | ADD, SUB, AND, OR, XOR, ADDI, LW, SW, BEQ, BNE |
| Phase 2 execution | [rv32i_core](rtl/rv32i_core.v) integrates 12 blocks. [rv32i_top](rtl/rv32i_top.v) exposes the PC, instruction and completion signal. |
| Storage | 32 registers of 32 bits with x0 fixed at zero. The core defaults to 64 instruction words and 256 data words. Memories use byte addresses. |
| State updates | Rising edges commit the PC and enabled writes. Word loads read RAM combinationally. Reset sets PC to zero and suppresses register and RAM writes. |
| Control flow | Sequential PC is PC + 4. A taken branch selects the branch instruction's PC plus its signed byte offset. Programs end with a self-branch observed by the wrapper. |
| Phase 1 baseline | The [arithmetic core](rtl/rv32i_phase1_core.v) and its original tests are retained. The final regression includes these earlier suites. |

The [integrated datapath diagram](docs/phase2_integration_guide.md) shows the connections. The [control table](docs/control_phase1_guide.md) identifies which signals change for each instruction. The [architecture comparison](docs/comparison.md) explains the trade-offs among single-cycle, multi-cycle and pipelined implementations.

## Assembly, lint and synthesis

These workflows can be run independently of the simulation regression.

| Task | Command | Requirements and output |
|---|---|---|
| Verify the six checked-in assembly images | `bash scripts/build_branch_programs.sh --check` | GNU RISC-V Binutils and Python 3. Rebuilt images and disassemblies go to `build/branch_programs/`. Set `CROSS_COMPILE` for a custom tool prefix. |
| Check RTL modules | `bash scripts/check_phase1_rtl.sh` | Verilator and Yosys. Checks module lint, synthesis and structural properties. |
| Synthesize the integrated core | `./synthesize.sh` | Verilator, Yosys and Icarus Verilog. Refreshes the tracked [netlist](netlist/rv32i_core_netlist.v) and [raw synthesis report](synthesis_report.txt). |
| Rebuild the paper | `cd docs && latexmk -pdf final_project_report.tex` | A LaTeX installation with IEEEtran and the packages listed in the source. Tectonic can also compile the same file. |

The committed generic mapping contains **9,248 flip-flops** and **9,543 multiplexers**. The register file and data RAM account for 9,216 enabled storage bits. The load combines address addition, RAM read and register writeback within one clock period. The team's **70–140 MHz** range is an illustrative calculation from assumed gate delays. A device rating requires a target, constraints and routed timing. See the [resource breakdown](docs/synthesis.md) and [timing model](timing_analysis.md).

## Team contributions

| Member | Phase 1 | Phase 2 |
|---|---|---|
| Ankit | PC, instruction memory and fetch | Integrated core, wrapper and final datapath |
| Rashmi | Register file and data memory | Load/store integration, tests and waveforms |
| Ayush | ALU and ALU control | Integrated arithmetic and branch comparison, synthesis and timing |
| Samiksha | Main control and initial verification | Branch execution, PC routes and assembly programs (M13) |
| Saumya | Immediate generator, multiplexers and branch target | Whole-processor acceptance, automated regression and final documentation (M14/M16) |

## Repository guide

- [RTL](rtl/) and [testbenches](testbench/) contain the implementation and its self-checking simulations. The [final acceptance bench](testbench/tb_final_verification.v) reads the [annotated machine-code image](programs/final_verification.hex).
- [Programs](programs/) and [scripts](scripts/) contain assembly, ROM images, build commands and individual simulation runners.
- [Phase 1 IEEE report](docs/phase1-report.pdf) · [Phase 1 LaTeX source](docs/phase1-report.tex) · [Prototype video](https://drive.google.com/file/d/1h3wr6jaVHCT1d3m6KTbqFU8Jfo3WYwjh/view) · [Project video folder](https://drive.google.com/drive/folders/1daOmAHnOrNh-L1YhrbRlE5GaWKV3XGjL?usp=sharing)
