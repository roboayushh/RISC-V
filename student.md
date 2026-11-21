# Work Log — Phase 1 Fix-Up to 100%

> Personal log of changes made to bring Ankit's Phase 1 fetch-path to 100% on all
> checks (Icarus simulation, Verilator `-Wall` lint, Yosys synthesis, docs).
> This file is gitignored and is **not** part of the submitted deliverable.

Date: 2026-11-14

## Starting point (from the audit)

All 3 Icarus testbenches passed and Yosys synthesized cleanly, but three gaps kept
the project below 100%:

1. **Verilator lint error** — `instruction_memory.v:33` WIDTHTRUNC: the DEPTH-entry
   memory was indexed with the full 30-bit `address[31:2]` instead of a correctly
   sized word index. Functionally safe (guarded by a range check) but `-Wall` fails.
2. **Untested branch** — the `INIT_FILE == ""` (missing/empty init file) path in
   `instruction_memory.v` had no test coverage.
3. **Documentation** — `docs/architecture.md` only showed the fetch path, not the
   complete single-cycle datapath the architecture diagram is expected to describe.

## Changes made

### 1. rtl/instruction_memory.v — fix WIDTHTRUNC lint error
- Added `localparam ADDR_WIDTH = $clog2(DEPTH);` (word-index width).
- Changed the read from `memory[address[31:2]]` to `memory[address[ADDR_WIDTH+1:2]]`,
  a correctly sized index. The existing `address[31:2] < DEPTH` range check already
  guarantees the upper address bits are zero in range, so behavior is unchanged — the
  index is now just the exact width Verilator expects.
- Result: Verilator `-Wall` now passes with no warnings. No functional change; all
  existing simulation results identical.

### 2. testbench/tb_instruction_memory.v — cover the empty-init-file branch
- Added a second DUT instance `dut_empty` parameterized with `INIT_FILE("")`.
- Added two self-checking cases asserting it returns NOP (`0x00000013`) at addresses
  `0x0` and `0x8`, exercising the previously untested `if (INIT_FILE != "")` guard.
- No existing checks changed; test still reports `INSTRUCTION MEMORY TEST PASSED`.

### 3. docs/architecture.md — add the complete datapath diagram
- Added a "Complete single-cycle RV32I datapath" section with a full Mermaid diagram
  (PC, IMEM, decode/control, register file, immediate generator, ALU + ALUSrc mux,
  data memory, write-back mux, branch unit, next-PC mux).
- Clearly marks which blocks are implemented in Phase 1 (fetch path) vs. which are the
  Phase 2 integration targets, so the diagram documents the architecture without
  claiming unimplemented hardware exists.

### 4. testbench/tb_instruction_memory.v + tb_rv32i_core.v — remove benign $readmemh note
- Icarus emitted `$readmemh ... Not enough words in the file for range [0:15]` because
  the test instantiated a 16-deep memory but the image has 4 words. Harmless, but not
  spotless.
- Set the loading instances' DEPTH to 4 (exact image size) so `$readmemh` fills the
  whole array — note gone. Out-of-range coverage preserved: addresses 0x10 and 0x40
  (indices >= 4) still return NOP via the range-guard branch.
- The empty-init instance stays DEPTH=16 with no init file, so it still covers the
  in-range-but-unloaded read path (pre-filled NOP) with no `$readmemh` call.
- The design default (DEPTH=256) and the documented 4-word image are unchanged; only
  testbench parameters were adjusted.

## Verification after changes (all clean)

Tools: Icarus Verilog 13.0, Verilator 5.054, Yosys 0.71 (installed via Homebrew).

1. **Icarus simulation** (`bash scripts/run_tests.sh`): all three suites pass —
   `PROGRAM COUNTER TEST PASSED`, `INSTRUCTION MEMORY TEST PASSED`,
   `RV32I FETCH-PATH TEST PASSED`, `ALL THREE TESTS PASSED`. No WARNING/ERROR lines.
2. **Verilator `-Wall`**: CLEAN on all three RTL modules (previous WIDTHTRUNC gone).
3. **Yosys synth**: CLEAN — no errors, no inferred latches. 90 cells, 30 sync-reset
   flip-flops (PC bits [1:0] optimized away as always-zero).

Final status: Phase 1 fetch path is 100% on simulation, lint, synthesis, and docs.
Nothing committed or pushed; `git status` shows only the modified source files.

---

# Part 2 — Rashmi's Phase 1 storage modules

Date: 2026-11-14 · Branch: `rashmi/phase1-storage`

## Scope
Implemented ONLY Rashmi's assigned storage components + testbenches + docs:
Register File and Data Memory. No ALU/control/PC/IMEM/immediate/integration (those
are other members' or Phase 2 work).

## Structure decision
Prompt said `rtl/` and `tb/`; repo isolates each member under their own folder
(`ankit_phase1/`). Chose `rashmi_phase1/rtl/` and `rashmi_phase1/tb/` to honor both
and guarantee Ankit's files are never touched.

## Files created
- `rashmi_phase1/rtl/register_file.v` — 32×32 RF, 2 async read, 1 sync write, x0=0.
- `rashmi_phase1/rtl/data_memory.v` — 256×32 (1 KiB), byte-addressed, async read, sync write.
- `rashmi_phase1/tb/tb_register_file.v` — 12-case self-checking TB.
- `rashmi_phase1/tb/tb_data_memory.v` — 15-case self-checking TB.
- `rashmi_phase1/scripts/run_tests.sh`, `docs/storage_modules.md`, `README.md`, `.gitignore`.

## Design notes
- Register file: async reads via continuous assigns with x0→0 mux; sync write guarded
  by `RegWrite && rd!=0`. No reset port (matches agreed interface); zero-init for sim.
- Data memory: word index = `address[$clog2(DEPTH)+1:2]`; aligned+in-range guards;
  read gated by MemRead (returns 0 otherwise); misaligned/out-of-range → no write, read 0.

## Verification (all clean)
- Icarus: `REGISTER FILE TEST PASSED` (12/12), `DATA MEMORY TEST PASSED` (15/15),
  `ALL STORAGE-MODULE TESTS PASSED`.
- Verilator `-Wall`: CLEAN on both modules.
- Yosys: CLEAN, no latches. RF = 1024 DFF (32×32); DMEM = 8192 DFF (256×32).
  DMEM maps to distributed RAM (async read) — matches documented single-cycle limitation.
- Waveforms: `build/tb_register_file.vcd`, `build/tb_data_memory.vcd` generated.

## Git
On branch `rashmi/phase1-storage`. NOT committed (awaiting Rashmi's approval).
At commit time, stage ONLY rashmi_phase1/ files (+ root .gitignore if wanted);
do NOT stage the uncommitted ankit_phase1 fixes or push to main.
Planned message: `feat(rtl): implement register file and data memory with testbenches`

---

# Part 3 — Repository structure standardization

Date: 2026-11-14

## Goal
Remove member-specific folders (`ankit_phase1/`, `rashmi_phase1/`) and consolidate all
work into standard flat folders: `rtl/`, `testbench/`, `scripts/`, `docs/`, `programs/`.
No Verilog logic, module names, ports, or testbench logic changed. Nothing deleted,
nothing committed.

## Moves (old -> new)
- ankit_phase1/rtl/*.v                 -> rtl/
- ankit_phase1/testbench/*.v           -> testbench/
- ankit_phase1/programs/test_program.hex -> programs/
- ankit_phase1/docs/architecture.md    -> docs/architecture.md
- ankit_phase1/scripts/run_tests.sh    -> scripts/run_fetch_tests.sh   [renamed: name clash]
- ankit_phase1/README.md               -> docs/fetch_path_guide.md     [renamed: name clash]
- rashmi_phase1/rtl/*.v                -> rtl/
- rashmi_phase1/tb/*.v                 -> testbench/
- rashmi_phase1/docs/storage_modules.md-> docs/storage_modules.md
- rashmi_phase1/scripts/run_tests.sh   -> scripts/run_storage_tests.sh [renamed: name clash]
- rashmi_phase1/README.md              -> docs/storage_guide.md        [renamed: name clash]

## Reference updates
- scripts/run_storage_tests.sh: tb/ -> testbench/.
- docs/storage_guide.md: layout tree, run command (run_storage_tests.sh), tb/ -> testbench/,
  internal link storage_modules.md.
- docs/fetch_path_guide.md: layout tree (flat RISC-V/), run command (run_fetch_tests.sh),
  architecture.md link, removed member name `rv32i_ankit` -> `RISC-V`.
- scripts/run_fetch_tests.sh: no change needed (already used rtl/ + testbench/ paths).

## Leftover conflict (NOT resolved by deleting, per instructions)
- ankit_phase1/ and rashmi_phase1/ still exist because each holds a redundant
  `.gitignore` (superseded by the root `.gitignore`) and a generated, gitignored
  `build/` directory. These are not source/work. Removing the two folders fully needs
  permission to delete those leftovers (or just leave them — they are gitignored).

## Verification
- `bash scripts/run_fetch_tests.sh` -> ALL THREE TESTS PASSED.
- `bash scripts/run_storage_tests.sh` -> ALL STORAGE-MODULE TESTS PASSED.
- All file references (rtl/, testbench/, programs/, $readmemh path) resolve from root.

---
---

# PHASE 2 — Data Memory Integration, LW/SW Execution & Memory Verification

Date: 2026-11-21 · Author: Rashmi · Tools: Icarus Verilog (`iverilog`/`vvp`), Verilator 5.054

> This is the Phase 2 journal. The Phase 1 sections above are kept intact as history.
> **Honesty note up front (important for the viva):** the data memory *module* and its
> *integration into the CPU* already existed before I started this Phase 2 task —
> `rtl/data_memory.v` is my own Phase 1 module (see "Part 2" above), and Ankit wired it
> into `rtl/rv32i_core.v` during his integration phase. My Phase 2 contribution is the
> **verification layer**: proving LW/SW/data-memory are correct end-to-end, authoring
> dedicated memory test programs and a self-checking testbench, and documenting the whole
> load/store datapath. I did **not** rewrite working RTL, and I do **not** claim Ankit's
> integration wiring as mine. Everything below is backed by real simulation output.

## 1. My Role and Responsibility

- **Name:** Rashmi.
- **Phase 2 assigned responsibility:** Data Memory Integration, LW/SW instruction
  execution, and memory verification.
- **Exact scope of my contribution in Phase 2:**
  - Verify the data memory module (`rtl/data_memory.v`) and its interface.
  - Verify the complete LW (load word) and SW (store word) execution paths through the
    integrated datapath.
  - Author dedicated memory test programs (`programs/mem_*.hex`).
  - Author a dedicated, self-checking memory-integration testbench
    (`testbench/tb_memory_integration.v`) + runner (`scripts/run_memory_integration.sh`).
  - Confirm arithmetic/branch instructions still work after memory is exercised
    (regression).
  - Maintain this journal.
- **What belongs to other teammates (NOT my work):**
  - Complete processor integration / top-level wiring — **Ankit** (`rtl/rv32i_core.v`,
    `rtl/rv32i_top.v`, `testbench/tb_rv32i_integration.v`).
  - Immediate generator, ALU source mux, write-back mux, branch target, next-PC mux —
    **Saumya** (`Author : Saumya` headers).
  - Main control unit, ALU, ALU control — team/other members.
  - Program counter, instruction memory, fetch path — **Ankit** (Phase 1 fetch).
  - Register file — my own Phase 1 storage work (shared storage area with data memory).

## 2. Initial Repository Understanding

Before writing anything I inspected the actual RTL (not generic RV32I examples):

- **Existing architecture:** a classic single-cycle RV32I datapath. Top-level
  `rv32i_top` (`rtl/rv32i_top.v`) wraps the integrated core `rv32i_core`
  (`rtl/rv32i_core.v`, instance name `u_core`), which instantiates all 12 leaf modules.
- **Modules I inspected:** `data_memory.v`, `rv32i_core.v`, `rv32i_top.v`,
  `control_unit.v`, `alu.v`, `alu_control.v`, `writeback_mux.v`, `register_file.v`,
  `immediate_generator.v`, `alu_src_mux.v`, plus Ankit's integration testbench.
- **Already implemented before my Phase 2 work:**
  - `rtl/data_memory.v` — complete (my Phase 1 module): 256×32-bit, byte-addressed,
    async read gated by `MemRead`, sync write gated by `MemWrite`, alignment + range guards.
  - LW/SW were **already wired and already passing** inside Ankit's `rv32i_core.v` and his
    `tb_rv32i_integration.v` (20/20 checks). So LW/SW were not "broken/incomplete"; they
    lacked a *dedicated, memory-focused* verification suite with edge cases.
- **What was missing before my work:** a focused memory testbench covering multiple
  locations, no-clobber, zero, full 32-bit values, positive **and negative** offsets,
  consecutive load/store, "SW must not write a register", and a memory+branch program —
  plus the technical write-up of the load/store datapath.
- **Dependencies on Ankit's integration:** my testbench reaches into the real hierarchy
  Ankit built — `dut.u_core.u_dmem.memory[...]` and `dut.u_core.u_regfile.registers[...]`.
  If he renamed those instances, my testbench paths would need updating. No conflict found;
  I did not need to modify any of his files.

## 3. Implementation Log

### Feature: Dedicated memory-integration testbench
- **What was required?** A self-checking testbench that verifies the LW/SW/data-memory
  datapath end-to-end against the *real* integrated processor (not a toy datapath).
- **What did I implement?** `testbench/tb_memory_integration.v` — it instantiates five
  real `rv32i_top` DUTs (`dut_basic`, `dut_multi`, `dut_consec`, `dut_mixed`,
  `dut_branch`), each loading one of my test programs, driven by one shared clock/reset.
  A generic `check(label, actual, expected)` task prints EXPECTED, ACTUAL and an explicit
  PASS/FAIL and counts errors. 34 checks total.
- **Why this approach?** Reusing `rv32i_top` means I test the actual integrated datapath
  and create **no parallel/duplicate datapath** (a requirement). Five DUTs let one `vvp`
  run cover all twelve required cases, because each program ends in `BEQ x0,x0,0` (halts
  by self-loop) so the final architectural state is stable when I sample it.
- **File modified/created:** created `testbench/tb_memory_integration.v`.
- **Signals/instances involved:** `dut_*.u_core.u_dmem.memory[word]`,
  `dut_*.u_core.u_regfile.registers[idx]`, `clk`, `reset`.
- **How it works:** hold `reset` high 2 cycles, release on a negedge, free-run 60 cycles,
  then read memory words and registers by hierarchical reference and compare.
- **Problems encountered + fix:** (1) long check labels were truncated in output because
  the task's string argument was only 320 bits wide → widened to `input [511:0] label`,
  reran, labels now print in full. (2) To avoid Icarus's benign "`$readmemh` not enough
  words" note, I set each DUT's `IMEM_DEPTH` to its program's exact word count.

### Feature: Memory test programs (hand-encoded, simulation-verified)
- **What was required?** Meaningful assembly test programs converted to hex, with no
  fabricated encodings.
- **What did I implement?** Five programs in `programs/`:
  `mem_basic.hex`, `mem_multi.hex`, `mem_consecutive.hex`, `mem_mixed.hex`, `mem_branch.hex`.
- **Why / encoding method:** No RISC-V assembler is installed on this machine
  (`riscv64-unknown-elf-as`, `llvm-mc` absent — checked). So I hand-encoded each
  instruction field-by-field from the RV32I spec, cross-checking opcode/format bytes
  against the already-verified `programs/phase2_integration.hex`, and then **validated
  every encoding end-to-end**: the self-checking testbench confirms each instruction
  produces its intended register/memory result. An encoding that was wrong would make a
  check FAIL. All 34 checks PASS → encodings are verified, not assumed.
- **Files created:** the five `programs/mem_*.hex` files (each line documents the
  instruction, fields and expected effect).

### Feature: Runner script
- Created `scripts/run_memory_integration.sh` (modeled on `scripts/run_phase2_integration.sh`):
  compiles all 12 RTL modules + `rv32i_core` + `rv32i_top` + my testbench with
  `iverilog -g2005`, runs `vvp`, emits `build/tb_memory_integration.vcd`.

### RTL changes
- **None.** `rtl/data_memory.v` was already correct; rewriting it would be an unnecessary
  change and would risk the rest of the integrated design. No teammate module was touched.

## 4. LW Instruction — Complete Technical Explanation

- **Instruction format:** I-type. Example `LW x3, 0(x1)` = `0x0000A183`.
  Fields: `imm[11:0]=instruction[31:20]`, `rs1=instruction[19:15]`,
  `funct3=instruction[14:12]=010`, `rd=instruction[11:7]`, `opcode=instruction[6:0]=0000011`.
- **Opcode + immediate extraction:** `control_unit.v` matches `OP_LOAD (7'b0000011)` with
  `funct3==010` and sets `RegWrite=1, ALUSrc=1, MemRead=1, ResultSrc=1, ALUOp=00, ImmSrc=00`
  (`rtl/control_unit.v:57-66`). `immediate_generator.v` with `ImmSrc=00` produces the
  sign-extended I-type immediate `{{20{instruction[31]}}, instruction[31:20]}`
  (`rtl/immediate_generator.v:71`).
- **Register reads:** `register_file.v` reads `rs1` → `reg_data1` (the base address).
- **Address calculation:** `ALUSrc=1` makes `alu_src_mux` pass `imm_ext` as operand B
  (`rtl/alu_src_mux.v:42`); `ALUOp=00` makes `alu_control` output ADD (`3'b000`); the ALU
  computes `alu_result = reg_data1 + imm_ext` = effective byte address (`rtl/alu.v:14`).
- **Memory read:** `data_memory u_dmem` gets `address=alu_result`, `MemRead=1`; it returns
  `read_data = memory[address>>2]` asynchronously (`rtl/data_memory.v:52-57`).
- **Write-back:** `ResultSrc=1` makes `writeback_mux` select `mem_read_data`
  (`rtl/writeback_mux.v:47`) → `write_back_data` → register file write port.
- **Register write:** on the next `posedge clk`, `register_file` writes `write_back_data`
  into `rd` because `RegWrite=1` (gated to `reg_write_en = RegWrite & ~reset`).
- **Datapath flow:** PC→IMEM→decode→(control + immgen)→ALU(base+imm)→DMEM read→WB mux→rd.
- **Implementation locations:** wiring in `rtl/rv32i_core.v:213-229` (dmem + wb mux);
  memory in `rtl/data_memory.v`. Verified by `mem_basic.hex` (x3=25) and others.

## 5. SW Instruction — Complete Technical Explanation

- **Instruction format:** S-type. Example `SW x2, 0(x1)` = `0x0020A023`.
  Fields: `imm[11:5]=instruction[31:25]`, `rs2=instruction[24:20]`,
  `rs1=instruction[19:15]`, `funct3=010`, `imm[4:0]=instruction[11:7]`,
  `opcode=0100011`.
- **S-type immediate generation:** `control_unit.v` matches `OP_STORE (7'b0100011)`,
  `funct3==010`, sets `ALUSrc=1, MemWrite=1, ALUOp=00, ImmSrc=01`, and crucially leaves
  `RegWrite=0` (`rtl/control_unit.v:68-75`). `immediate_generator.v` with `ImmSrc=01`
  builds `{{20{sign}}, instruction[31:25], instruction[11:7]}` (`:81`).
- **Source register reads:** `rs1` → `reg_data1` (base address); `rs2` → `reg_data2`
  (the data to store).
- **Address calculation:** ALU computes `reg_data1 + imm_ext` (ADD) = effective address.
- **Memory write:** `data_memory u_dmem` gets `address=alu_result`,
  `write_data=reg_data2`, `MemWrite=1` (gated to `mem_write_en = MemWrite & ~reset`); on
  `posedge clk` it does `memory[address>>2] <= write_data` when aligned & in range
  (`rtl/data_memory.v:60-63`).
- **Why SW does not write to rd:** `RegWrite=0` for the store opcode, so the register file
  write port is disabled. Note the S-type immediate's low 5 bits occupy the *same* bit
  positions `[11:7]` that `rd` uses in other formats — but because `RegWrite=0`, those bits
  are only interpreted as immediate, never as a write target. My `mem_multi.hex` proves
  this: `SW x5,4(x1)` has `imm[4:0]=00100` (the "x4" field) yet **x4 stays 0**.
- **Datapath flow:** PC→IMEM→decode→(control + immgen)→ALU(base+imm)→DMEM write; no WB.
- **Implementation locations:** `rtl/rv32i_core.v:213-222`; `rtl/data_memory.v:60-63`.

## 6. Memory Architecture and Design Decisions

- **Organization:** `reg [31:0] memory [0:DEPTH-1]`, `DEPTH=256` words = 256×32 bits =
  **1 KiB** (`rtl/data_memory.v:20-35`).
- **Addressing convention (explicitly inspected, not assumed):** **byte-addressed**. The
  word index is `address[INDEX_WIDTH+1:2]`, i.e. `byte_address >> 2`
  (`rtl/data_memory.v:41-42`). So byte address 64 → word index 16; 68 → 17; 60 → 15. My
  testbench and all program comments use exactly this convention.
- **Word size:** 32 bits (`DATA_WIDTH=32`). Full 32-bit values verified (0xFFFFFFFF).
- **Read/write mechanism:** asynchronous (combinational) read gated by `MemRead`;
  synchronous write on `posedge clk` gated by `MemWrite`. Separate enables match the
  LW/SW datapath.
- **Clocking:** only the write port is clocked; reads are combinational so the loaded
  value is available in the same cycle for single-cycle write-back.
- **Alignment handling:** `aligned = (address[1:0]==2'b00)`. Misaligned access performs
  **no write** and **reads 0** (`:39, :52-63`). All my accesses are 4-byte aligned.
- **Out-of-range handling:** `in_range = ({2'b00,address[31:2]} < DEPTH)`; out-of-range →
  no write, read 0.
- **Reset behavior:** the memory array has **no reset port**; it is zero-initialized in an
  `initial` block for deterministic simulation (`:46-49`). Writes are additionally
  suppressed during CPU `reset` by the core's `mem_write_en = MemWrite & ~reset`
  (`rtl/rv32i_core.v:99`). **Design limitation:** on an FPGA without initial-value support,
  contents power up undefined and must be written before read — documented, not hidden.
- **Why retained unmodified:** it already met every requirement (width, addressing,
  enables, guards) and passed its unit testbench; changing it would be an unnecessary
  rewrite and a regression risk.

## 7. Testing and Verification

- **Testbench:** `testbench/tb_memory_integration.v` (self-checking, 34 checks).
- **Programs:** `programs/mem_basic.hex`, `mem_multi.hex`, `mem_consecutive.hex`,
  `mem_mixed.hex`, `mem_branch.hex`.
- **Command:** `bash scripts/run_memory_integration.sh`
  (compiles with `iverilog -g2005`, runs `vvp`, writes `build/tb_memory_integration.vcd`).
- **Result:** `MEMORY INTEGRATION TEST PASSED (34/34 checks)` — real output, all PASS.

| Test Case | Expected Result | Actual Result | Status |
|---|---|---|---|
| 1. Store a positive integer (SW x2,0(x1)) | mem[16]=25 | mem[16]=0x19 | PASS |
| 2. Load the stored integer (LW x3) | x3=25 | x3=0x19 | PASS |
| 3. Store & load zero | mem[16]=0, x3=0 | 0, 0 | PASS |
| 4. Store & load large 32-bit value | mem[18]=0xFFFFFFFF, x8=0xFFFFFFFF | match | PASS |
| 5. Different memory locations | mem[16]=100, mem[17]=200 | 0x64, 0xC8 | PASS |
| 6. Writing one loc doesn't modify another | x3 (LW A)=100 after SW B | 0x64 | PASS |
| 7. LW writes correct destination reg | x6 (rd)=200 | 0xC8 | PASS |
| 8. SW does not write a register | x4=0 (SW imm field) | 0 | PASS |
| 9. Non-zero positive offset (+4,+8) | mem[17],mem[18] correct | match | PASS |
| 10. Negative offset (-4) | mem[15]=0xFFFFFFFF, x9=0xFFFFFFFF | match | PASS |
| 11. Consecutive SW then LW | x8=0xFFFFFFFF | match | PASS |
| 12. Arithmetic intact around memory | x4=12,x5=2,x7=14,x9=2,x10=5,x11=7 | match | PASS |
| (bonus) Memory + taken branches | x5=0,x6=7,x8=0,x9=3,mem[17]=7 | match | PASS |

- **Regression (existing suites, unchanged RTL) — all re-run, all PASS:**
  `run_phase1_tests` (fetch trio), `run_alu_tests` (ALL ALU TESTS PASSED),
  `run_saumya_tests` (ALL SAUMYA MODULE TESTS PASSED),
  `run_storage_tests` (ALL STORAGE-MODULE TESTS PASSED),
  `run_fetch_tests`, `run_full_cpu_test` (FULL CPU TEST PASSED),
  `run_phase2_integration` (PHASE 2 INTEGRATION TEST PASSED, 20/20).
  Verilator `--lint-only -Wall` on the full `rv32i_top` hierarchy: **clean (exit 0)**.
- **Waveform generated:** `build/tb_memory_integration.vcd` (GTKWave not installed on this
  machine; VCD can be opened on any machine that has it).
- **Bugs found & fixed:** no RTL bugs. Two cosmetic testbench issues fixed (label width,
  IMEM depth) — see §8.
- **Tests that remain incomplete:** byte/half-word accesses (LB/LH/SB/SH) are out of the
  agreed 10-instruction scope and not tested; hardware misaligned/out-of-range behaviour is
  covered at unit level in `tb_data_memory.v`, not re-exercised at CPU level here.

## 8. Problems and Debugging Journal

1. **Output labels truncated** (e.g. "asic:" instead of "basic:").
   - Root cause: `check` task's string argument reg was `[319:0]` (40 chars); several
     labels were longer, so Verilog dropped the leading characters.
   - Fix: widened to `input [511:0] label`; reran — labels now print fully. Values and
     PASS/FAIL were always correct; purely cosmetic.
2. **`$readmemh` "not enough words" note.**
   - Root cause: a DUT's `IMEM_DEPTH` larger than the program's word count leaves trailing
     array entries unfilled.
   - Fix: set each DUT's `IMEM_DEPTH` to the exact program length. Note gone.
3. **No assembler available** (would normally produce hex).
   - Root cause: `riscv*-as` / `llvm-mc` not installed.
   - Fix/verification: hand-encoded field-by-field, cross-checked against the verified
     `phase2_integration.hex`, and relied on the self-checking sim as the end-to-end
     validator (a wrong encoding would fail a check). All 34 checks pass.

## 9. Final Contribution Summary

- **Implemented by me (new, Phase 2):**
  `testbench/tb_memory_integration.v`, `scripts/run_memory_integration.sh`,
  `programs/mem_basic.hex`, `programs/mem_multi.hex`, `programs/mem_consecutive.hex`,
  `programs/mem_mixed.hex`, `programs/mem_branch.hex`, and this Phase 2 journal.
- **Existed before my Phase 2 contribution:** `rtl/data_memory.v` (my own Phase 1
  module), and the LW/SW wiring inside `rtl/rv32i_core.v` / `rtl/rv32i_top.v` (**Ankit's**
  integration) and the leaf modules by Saumya and others.
- **Modified by me:** no RTL. Only one of my own new testbench files was edited twice
  during debugging. `student.md` was appended to (Phase 1 history preserved).
- **Completed jointly:** data-memory correctness is a joint result — my module +
  Ankit's integration + Saumya's immediate/mux modules all cooperate on every LW/SW.
- **Still pending:** none within my assigned scope. Out of scope: byte/half-word
  loads/stores, which would need control-unit + data-memory width-select changes
  (coordinate with the control-unit owner and Ankit if ever added).

## 10. Viva Preparation — Questions and Answers

**Q1. Why is data memory needed?**
Simple: registers are few (32) and temporary; data memory is the larger store where a
program keeps values that don't fit in registers or must persist across many instructions.
Technical: LW/SW are the only instructions in our set that move data between the register
file and `data_memory`; it gives the CPU a 1 KiB (256×32) addressable data space.

**Q2. Difference between LW and SW?**
Simple: LW reads a word *from* memory *into* a register; SW writes a register's value *to*
memory. Technical: both compute the address as `rs1 + immediate` in the ALU. LW asserts
`MemRead`+`ResultSrc`+`RegWrite` and ends by writing `rd`. SW asserts `MemWrite` only, with
`RegWrite=0`, and writes `memory[addr>>2] <= rs2`.

**Q3. How does the ALU calculate the effective address?**
`ALUSrc=1` routes the sign-extended immediate to ALU operand B; `ALUOp=00` selects ADD; so
`alu_result = reg_data1(base) + imm_ext(offset)`. That result is the byte address sent to
`data_memory`.

**Q4. What is an I-type and an S-type instruction?**
I-type packs a single 12-bit immediate in `instruction[31:20]` (used by LW, ADDI). S-type
splits its 12-bit immediate into `instruction[31:25]` (high) and `instruction[11:7]` (low)
so that `rs1`/`rs2` keep fixed positions (used by SW). `immediate_generator.v` reassembles
each correctly based on `ImmSrc`.

**Q5. Why does LW use memory data for write-back?**
Because the value LW must put in `rd` comes from memory, not the ALU. The ALU only computed
the *address*; so `ResultSrc=1` makes `writeback_mux` pick `mem_read_data` instead of
`alu_result`.

**Q6. Why does SW not update the register file?**
Because a store produces no register result. `control_unit.v` sets `RegWrite=0` for the
store opcode, disabling the register write port. Even though the S-type immediate reuses
the `rd` bit positions, those bits are treated purely as immediate.

**Q7. What is `MemRead`?**
A control signal that enables a memory read. In `data_memory.v` the read returns the stored
word only when `MemRead=1` (otherwise it drives 0), so a non-load instruction can't leak
stale memory data into the datapath.

**Q8. What is `MemWrite`?**
A control signal that enables a memory write on the clock edge. Only SW sets it; it's also
gated by `~reset` in the core so no write happens during reset.

**Q9. How does the memory connect to the datapath?**
`address` ← ALU result; `write_data` ← register file `reg_data2` (rs2); `read_data` →
`writeback_mux` → register file write port; `MemRead`/`MemWrite` ← control unit. Wiring is
in `rtl/rv32i_core.v:213-229`.

**Q10. Why does a single-cycle processor execute each instruction in one clock cycle?**
Because the whole datapath is combinational from PC to write-back, except the state
elements (PC, register file write, memory write) that update on one clock edge. Memory read
is asynchronous, so the loaded value is ready within the same cycle to be written back.

**Q11. What is the memory addressing convention here, and how did you confirm it?**
Byte-addressed; word index = `address>>2` (`data_memory.v:41-42`). I confirmed it by
reading the RTL, then my programs use base 64 and I check word index 16 — consistent.

**Q12. What problems did you encounter?**
No RTL bugs. A truncated-label display bug and a benign `$readmemh` note in my own
testbench (both fixed), and the lack of an assembler (solved by verified hand-encoding).

**Q13. What exactly did you contribute?**
The memory *verification* for Phase 2: 5 test programs, a 34-check self-checking testbench
against the real integrated CPU, a runner, and this documentation — plus the data-memory
*module* itself from Phase 1. I did not write the integration wiring (that's Ankit's).

**Q14. Why five separate DUTs instead of one big program?**
Each `rv32i_top` instance loads exactly one instruction-memory image, and keeping programs
small and independent makes each failure easy to localise, while still covering all 12
cases in one simulation run.

## 11. Current Project Status

- **Completed (my scope):** data memory verified in-situ; LW and SW verified end-to-end;
  multiple locations, no-clobber, zero, 32-bit, ±offsets, consecutive load/store, SW-no-reg,
  and memory+branch all pass (34/34); arithmetic regression intact.
- **Partially completed:** none in scope.
- **Pending:** none in scope (byte/half-word memory ops are out of scope).
- **Test results:** `MEMORY INTEGRATION TEST PASSED (34/34)`; all 7 existing suites PASS;
  Verilator `-Wall` clean.
- **Known limitations:** single-cycle 1 KiB word memory; no reset port on the array (sim
  zero-init); misaligned/out-of-range handled by returning 0 / ignoring the write;
  GTKWave not installed locally (VCD still generated).
- **Next steps:** (optional) open `build/tb_memory_integration.vcd` in GTKWave on a machine
  that has it for a waveform figure; if the project later adds LB/LH/SB/SH, coordinate
  control-unit + data-memory changes with the owners.
