# Ankit's Phase 1 — RV32I Fetch Path

This folder contains **only Ankit's assigned Phase 1 work** for the Single-Cycle RISC-V RV32I Processor project:

- 32-bit Program Counter (PC)
- Instruction Memory
- Initial top-level module connecting the PC and Instruction Memory
- Unit testbenches and an integrated fetch-path testbench
- A sample instruction image
- Fetch-path architecture documentation
- A script to compile and run all three testbenches

> **Scope:** This is the instruction-fetch portion of the processor, not a complete RV32I CPU. It fetches one 32-bit instruction and advances the PC by 4. It does not decode or execute instructions. The ALU, register file, data memory, immediate generator, control unit, branches, jumps, and writeback are outside this package.

---

## 1. What you need

These instructions are written for **macOS**.

| Tool | Required? | Why it is needed |
|---|---|---|
| Terminal | Yes | Install tools and run simulation commands |
| Homebrew | Recommended | Installs Icarus Verilog and the waveform viewer |
| Icarus Verilog | Yes | Compiles the Verilog source files (`iverilog`) |
| VVP | Yes; installed with Icarus Verilog | Runs the compiled simulations (`vvp`) |
| Visual Studio Code | Recommended | Opens and edits the Verilog files |
| Surfer | Optional | Opens waveform files so you can inspect signals over time |

You do not need Python, Node.js, a RISC-V compiler, an FPGA board, or a GitHub account to run these testbenches.

---

## 2. Install the required tools on macOS

### Step 2.1 — Open Terminal

Open **Finder → Applications → Utilities → Terminal**, or press `Command + Space`, search for `Terminal`, and open it.

Check your Mac architecture (this is informational; Homebrew selects the appropriate package):

```bash
uname -m
```

- `arm64` means Apple silicon (M-series).
- `x86_64` means an Intel Mac.

### Step 2.2 — Install Apple's command-line tools

Run:

```bash
xcode-select --install
```

If macOS says the tools are already installed, continue. Otherwise, follow the installation prompt.

### Step 2.3 — Install Homebrew

Check whether Homebrew is already installed:

```bash
brew --version
```

If the command is not found, install Homebrew using its official installer:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Follow the installer's on-screen **Next steps**. On Apple silicon, Homebrew is normally installed under `/opt/homebrew`; the installer may ask you to add it to your shell environment. For the default Apple-silicon installation, the commands are:

```bash
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
```

For an Intel Mac, follow the PATH instructions printed by the installer rather than copying the Apple-silicon path above.

Confirm Homebrew works:

```bash
brew --version
```

### Step 2.4 — Install Icarus Verilog

Run:

```bash
brew install icarus-verilog
```

This installs both tools needed for the project:

- `iverilog` — compiles Verilog source and testbench files.
- `vvp` — executes the compiled simulation.

Check that both commands are available:

```bash
iverilog -V
vvp -V
```

You should see version information. The exact version number may differ.

### Step 2.5 — Install Visual Studio Code

1. Open the [Visual Studio Code download page](https://code.visualstudio.com/Download).
2. Download the macOS build that matches your Mac, or the Universal build.
3. Open the downloaded `.dmg` file.
4. Drag **Visual Studio Code.app** into the **Applications** folder.
5. Open Visual Studio Code.

To enable the `code` command in Terminal:

1. In VS Code, press `Command + Shift + P` to open the Command Palette.
2. Search for `Shell Command: Install 'code' command in PATH`.
3. Select it.
4. Close and reopen Terminal.

You can verify it with:

```bash
code --version
```

If you do not want to configure the `code` command, you can open VS Code normally and use **File → Open Folder** instead.

### Step 2.6 — Install a waveform viewer (optional, recommended)

The testbenches create `.vcd` waveform files. A waveform viewer lets you inspect the clock, reset, PC, and instruction signals visually.

For this project, use **Surfer**:

```bash
brew install surfer
```

Verify the installation:

```bash
surfer --version
```

Surfer supports VCD files and can open a waveform directly from Terminal. GTKWave is another known waveform viewer, but its macOS installation can require extra steps; Surfer is the simpler Homebrew route at the time this guide was written.

---

## 3. Get the project files

1. Clone or download the project repository (folder name `RISC-V`).
2. Keep the folder layout intact. Do not move individual Verilog files out of their
   folders because the compile commands and instruction-image path rely on this layout.

The repository uses a shared flat layout (the fetch-path files are highlighted):

```text
RISC-V/
├── README.md
├── .gitignore
├── docs/
│   ├── architecture.md
│   ├── fetch_path_guide.md
│   ├── storage_guide.md
│   └── storage_modules.md
├── programs/
│   └── test_program.hex          # fetch path
├── rtl/
│   ├── program_counter.v         # fetch path
│   ├── instruction_memory.v      # fetch path
│   ├── rv32i_core.v              # fetch path
│   ├── register_file.v
│   └── data_memory.v
├── scripts/
│   ├── run_fetch_tests.sh        # fetch path
│   └── run_storage_tests.sh
└── testbench/
    ├── tb_program_counter.v      # fetch path
    ├── tb_instruction_memory.v   # fetch path
    ├── tb_rv32i_core.v           # fetch path
    ├── tb_register_file.v
    └── tb_data_memory.v
```

The `build/` folder is generated automatically when you run the tests. It contains compiled simulation files and waveform files.

---

## 4. Open the project in VS Code

### Option A — Open it from Terminal

In Terminal, change directory to the project folder. For example:

```bash
cd /path/to/RISC-V
```

Replace the path with wherever you cloned the repository. A simple alternative is to type `cd ` (include a space) in Terminal, drag the `RISC-V` folder from Finder into the Terminal window, and press Enter.

Confirm that you are in the correct directory:

```bash
pwd
ls
```

You should see `README.md`, `rtl`, `testbench`, `programs`, and `docs` in the listing.

Open the current folder in VS Code:

```bash
code .
```

### Option B — Open it from VS Code

1. Open VS Code.
2. Select **File → Open Folder**.
3. Select the `RISC-V` folder (the repository root containing `README.md`).
4. Select **Open**.

### Open the integrated terminal

In VS Code, select **Terminal → New Terminal**. Check that the terminal is at the project root. If it is not, run `cd` to the folder containing `README.md`.

**Important:** Run the simulation commands from the project root, not from inside `rtl/`, `testbench/`, or `programs/`. The Instruction Memory loads `programs/test_program.hex` using a relative path.

---

## 5. Run all tests — recommended method

This is the easiest way to compile and test all your modules.

From the project root, run:

```bash
bash scripts/run_fetch_tests.sh
```

The script will:

1. Check that `iverilog` and `vvp` are installed.
2. Create the `build/` folder if it does not exist.
3. Compile the Program Counter testbench.
4. Run the Program Counter simulation and check its PASS result.
5. Compile and run the Instruction Memory testbench.
6. Compile and run the integrated fetch-path testbench.
7. Stop and report an error if compilation fails or a testbench does not print its expected PASS message.

At the end, a successful run should show these three result lines:

```text
PROGRAM COUNTER TEST PASSED
INSTRUCTION MEMORY TEST PASSED
RV32I FETCH-PATH TEST PASSED
```

It should also print:

```text
ALL THREE TESTS PASSED
```

The exact PASS lines are the checks to look for. If any test reports `FAILED`, or the script stops with an error, the test suite has not passed.

---

## 6. Run each test separately (optional)

Use these commands if you want to test one module at a time. Run them from the project root.

First create the build folder:

```bash
mkdir -p build
```

### 6.1 Program Counter

Compile:

```bash
iverilog -g2005 -o build/tb_program_counter \
  rtl/program_counter.v \
  testbench/tb_program_counter.v
```

Run:

```bash
vvp build/tb_program_counter
```

Expected final status:

```text
PROGRAM COUNTER TEST PASSED
```

### 6.2 Instruction Memory

Compile:

```bash
iverilog -g2005 -o build/tb_instruction_memory \
  rtl/instruction_memory.v \
  testbench/tb_instruction_memory.v
```

Run:

```bash
vvp build/tb_instruction_memory
```

Expected final status:

```text
INSTRUCTION MEMORY TEST PASSED
```

### 6.3 Integrated fetch path

Compile all three RTL modules with the integration testbench:

```bash
iverilog -g2005 -o build/tb_rv32i_core \
  rtl/program_counter.v \
  rtl/instruction_memory.v \
  rtl/rv32i_core.v \
  testbench/tb_rv32i_core.v
```

Run:

```bash
vvp build/tb_rv32i_core
```

Expected final status:

```text
RV32I FETCH-PATH TEST PASSED
```

---

## 7. View the waveforms (optional)

Each testbench writes a VCD waveform file when it runs. The `build/` directory should contain:

```text
build/
├── tb_program_counter.vcd
├── tb_instruction_memory.vcd
└── tb_rv32i_core.vcd
```

Open the integrated processor fetch waveform with Surfer:

```bash
surfer build/tb_rv32i_core.vcd
```

Or open a unit-test waveform:

```bash
surfer build/tb_program_counter.vcd
surfer build/tb_instruction_memory.vcd
```

In the waveform viewer:

1. Find the testbench hierarchy in the signal list.
2. Add the signals you want to inspect to the waveform pane.
3. For the PC test, inspect `clk`, `reset`, `next_pc`, and `pc`.
4. For the instruction-memory test, inspect `address` and `instruction`.
5. For the integrated test, inspect `clk`, `reset`, `pc`, and `instruction`.
6. Zoom to fit the complete simulation if the signals are not immediately visible.

The `.vcd` files are generated output. You can regenerate them at any time by running the tests again.

---

## 8. What the test program contains

`programs/test_program.hex` contains four 32-bit instruction words:

| Byte address | Machine code | Instruction meaning |
|---:|---|---|
| `0x00000000` | `00500093` | `ADDI x1, x0, 5` |
| `0x00000004` | `00A00113` | `ADDI x2, x0, 10` |
| `0x00000008` | `002081B3` | `ADD x3, x1, x2` |
| `0x0000000C` | `00302023` | `SW x3, 0(x0)` |

These are machine-code words loaded into Instruction Memory. **This Phase 1 fetch path only reads and outputs the instruction bits. It does not execute these operations or update registers/memory.**

After the four loaded words, unused memory locations return the RISC-V NOP encoding `32'h00000013`.

---

## 9. What each Verilog module does

### `rtl/program_counter.v`

- Stores a 32-bit program counter.
- Uses a rising-edge clock.
- Has a synchronous, active-high reset.
- Loads address `0x00000000` when reset is asserted at a rising clock edge.
- Otherwise loads the value supplied to `next_pc`.

The Program Counter itself does not calculate `PC + 4`; that calculation is in `rv32i_core.v`.

### `rtl/instruction_memory.v`

- Stores 32-bit instruction words.
- Loads the program image using `$readmemh`.
- Uses byte addresses; bits `[31:2]` select a 32-bit instruction word.
- Provides a combinational read.
- Returns NOP for misaligned or out-of-range addresses.

### `rtl/rv32i_core.v`

- Connects the Program Counter to Instruction Memory.
- Calculates `pc + 4` for the next sequential instruction address.
- Outputs the current `pc` and fetched `instruction`.
- Does not yet contain decode, execute, branch, jump, memory-write, or register-write logic.

For a block diagram and design assumptions, see [`architecture.md`](architecture.md).

---

## 10. Troubleshooting

### `zsh: command not found: brew`

Homebrew is not installed or is not in your shell PATH. Reopen Terminal after installation and follow the Homebrew installer's printed **Next steps**. On the default Apple-silicon setup, the shell initialization commands are shown in Step 2.3.

### `zsh: command not found: iverilog` or `vvp`

Install Icarus Verilog:

```bash
brew install icarus-verilog
```

Then close and reopen Terminal and check:

```bash
which iverilog
which vvp
iverilog -V
vvp -V
```

### `zsh: command not found: code`

The VS Code command-line launcher is not in PATH. Follow Step 2.5 to run **Shell Command: Install 'code' command in PATH**. You can also open the folder from VS Code using **File → Open Folder**.

### `$readmemh` cannot find `programs/test_program.hex`

You are probably running the simulation from the wrong directory, or the `programs` folder was moved. Change to the folder containing `README.md` and confirm the file exists:

```bash
pwd
ls programs/test_program.hex
```

Then rerun the test.

### `Unknown module type: program_counter` or `instruction_memory`

The compile command is missing a required RTL source file. Use the full commands in Section 6, or run the complete script:

```bash
bash scripts/run_fetch_tests.sh
```

### The waveform file does not exist

Run the corresponding testbench first. The testbench creates the `.vcd` file during simulation. Also confirm that the `build/` folder exists:

```bash
mkdir -p build
bash scripts/run_fetch_tests.sh
```

### `surfer: command not found`

Install Surfer and reopen Terminal:

```bash
brew install surfer
```

If you do not want to install a waveform viewer now, you can still compile and run every test. Waveform viewing is optional.

### The test prints `FAILED`

Do not treat the simulation as successful. Read the `expected` and `got` values in the failure line, confirm that you are using the project files together, and rerun the test. Keep the complete terminal output so the issue can be diagnosed.

---

## 11. Quick start — after the first-time setup

Once Homebrew, Icarus Verilog, and the project folder are ready, the normal workflow is only:

```bash
cd /path/to/RISC-V
code .
bash scripts/run_fetch_tests.sh
surfer build/tb_rv32i_core.vcd
```

Replace `/path/to/RISC-V` with the actual location of the extracted folder. The last command is optional and opens the integrated waveform.

---

## 12. Project scope and integration reminder

This package is for Ankit's Phase 1 responsibility only: Program Counter, Instruction Memory, and their initial fetch-path connection. It is not the team's final processor.

Before integrating with the other members' modules, the team should agree on the final reset convention, module port names, and top-level interface. In later phases, the simple `PC + 4` path will need next-PC selection for branches and jumps, and the remaining datapath/control modules will be connected.

---

## Official installation references

- [Homebrew installation](https://brew.sh/)
- [Icarus Verilog Homebrew package](https://formulae.brew.sh/formula/icarus-verilog)
- [Visual Studio Code for macOS](https://code.visualstudio.com/docs/setup/mac)
- [Surfer waveform viewer and documentation](https://surfer-project.org/)
