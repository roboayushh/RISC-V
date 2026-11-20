# Rashmi's Phase 1 — RV32I Storage Modules

This guide covers **Rashmi's assigned Phase 1 work** for the Single-Cycle
RISC-V RV32I Processor project: the processor's two storage components.

- **Register File** — 32 × 32-bit, 2 async read ports, 1 sync write port, x0 = 0.
- **Data Memory** — 256 × 32-bit (1 KiB), byte-addressed, async read, sync write.
- Self-checking testbenches for both modules.
- Module/interface and integration documentation.
- A script to compile and run both testbenches.

> **Scope:** These are standalone storage modules, not a complete CPU. They do not
> decode or execute instructions and do not include the ALU, control unit, immediate
> generator, muxes, PC, instruction memory, or CPU integration. Those belong to other
> team members or to Phase 2.

## Layout

The storage modules live in the repository's shared flat structure:

```text
rtl/
├── register_file.v
└── data_memory.v
testbench/
├── tb_register_file.v
└── tb_data_memory.v
scripts/
└── run_storage_tests.sh
docs/
├── storage_guide.md        (this file)
└── storage_modules.md      (interface + integration reference)
```

`build/` is generated when you run the tests (compiled sims + `.vcd` waveforms).

## Requirements (macOS)

- **Icarus Verilog** (`iverilog`, `vvp`) — compile and run the testbenches.
- **Verilator** (optional) — RTL linting.
- **Yosys** (optional) — synthesis checks.
- **Surfer** (optional) — waveform viewing.

```bash
brew install icarus-verilog verilator yosys surfer
```

## Run the tests

From the repository root:

```bash
bash scripts/run_storage_tests.sh
```

Expected final lines:

```text
REGISTER FILE TEST PASSED
DATA MEMORY TEST PASSED
ALL STORAGE-MODULE TESTS PASSED
```

### Run individually

```bash
mkdir -p build
iverilog -g2005 -o build/tb_register_file rtl/register_file.v testbench/tb_register_file.v
vvp build/tb_register_file

iverilog -g2005 -o build/tb_data_memory  rtl/data_memory.v  testbench/tb_data_memory.v
vvp build/tb_data_memory
```

### Lint / synthesis (optional)

```bash
verilator --lint-only -Wall rtl/register_file.v
verilator --lint-only -Wall rtl/data_memory.v
yosys -p "read_verilog rtl/register_file.v; synth -top register_file; stat"
yosys -p "read_verilog rtl/data_memory.v;  synth -top data_memory;  stat"
```

### View waveforms (optional)

```bash
surfer build/tb_register_file.vcd
surfer build/tb_data_memory.vcd
```

See [`storage_modules.md`](storage_modules.md) for full interface tables
and integration notes.
