# Ayush Phase 1: ALU and ALU control

This branch adds standalone, combinational execution modules. The current
`rv32i_core.v` remains the instruction-fetch scaffold; it does not yet decode or
execute instructions.

## Interfaces

`alu.v` takes 32-bit operands `a` and `b`, a 3-bit `alu_control`, and produces a
32-bit `result` plus `zero = (result == 0)`. ADD and SUB use 32-bit modular
arithmetic: carry and signed overflow wrap around. There is no overflow output.
The zero flag can be used after SUB for BEQ/BNE equality comparisons.

| `alu_control` | Operation |
|---|---|
| `000` | ADD |
| `001` | SUB |
| `010` | AND |
| `011` | OR |
| `100` | XOR |
| Other | Result 0 (unsupported) |

`alu_control.v` takes the main decoder's 2-bit `alu_op`, instruction `funct3`,
and instruction bit 30 (`funct7_bit5`). Its output `operation` connects directly
to `alu.alu_control`.

| `alu_op` | Use | `operation` |
|---|---|---|
| `00` | ADDI, LW, SW address calculation | ADD |
| `01` | BEQ/BNE equality comparison | SUB |
| `10` | R-type ADD/SUB/AND/OR/XOR | Decode `funct3` and bit 30 |
| `11` | Unsupported | `111` |

For R-type (`alu_op=10`), `funct3=000` selects ADD when bit 30 is 0 and SUB
when it is 1. `funct3=111/110/100` selects AND/OR/XOR when bit 30 is 0.
Unsupported combinations return `111`. The future instruction decoder must
validate opcode and the remaining `funct7` bits; this module does not take them.
An unsupported code drives ALU result 0, so its zero flag must not be used as
a branch decision.

## Test on macOS (Apple Silicon)

From the repository root:

```bash
brew install icarus-verilog
bash scripts/run_alu_tests.sh
```

The script compiles and runs `tb_alu.v` (17 cases) and `tb_alu_control.v`
(14 cases), writing waveforms under `build/`. Success prints:

```text
ALU TEST PASSED (17 cases)
ALU CONTROL TEST PASSED (14 cases)
ALL ALU TESTS PASSED
```

Optional checks, if Verilator and Yosys are installed:

```bash
verilator --lint-only -Wall rtl/alu.v
verilator --lint-only -Wall rtl/alu_control.v
yosys -p 'read_verilog rtl/alu.v; synth -top alu; stat'
yosys -p 'read_verilog rtl/alu_control.v; synth -top alu_control; stat'
```
