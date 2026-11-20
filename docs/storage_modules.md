# Phase 1 Storage Modules — Register File & Data Memory

Author: Rashmi · Scope: Phase 1 storage components only (Register File, Data Memory).
These are standalone, independently verified modules intended for later integration
into the team's single-cycle RV32I processor. They do **not** implement CPU
integration, the ALU, control, immediates, or branch/LW/SW datapath wiring.

## 1. Register File (`rtl/register_file.v`)

A 32 × 32-bit register file with two asynchronous read ports and one synchronous
write port.

| Port | Dir | Width | Function |
|---|---|---|---|
| `clk` | in | 1 | Clock; writes commit on the rising edge |
| `rs1` | in | 5 | First read-port register address |
| `rs2` | in | 5 | Second read-port register address |
| `rd` | in | 5 | Write-port register address |
| `write_data` | in | 32 | Data written to `rd` when `RegWrite=1` |
| `RegWrite` | in | 1 | Write enable |
| `read_data1` | out | 32 | Value of `rs1` (0 if `rs1=x0`) |
| `read_data2` | out | 32 | Value of `rs2` (0 if `rs2=x0`) |

Behavior:
- **Asynchronous reads:** `read_data1/2` follow `rs1/rs2` combinationally.
- **x0 hardwired to zero:** reads of address 0 return 0; writes with `rd=0` are ignored.
- **Synchronous write:** on `posedge clk`, `registers[rd] <= write_data` when
  `RegWrite=1` and `rd != 0`.
- **No reset port:** registers are zero-initialized for simulation (see synthesis note).

Synthesis: 1024 flip-flops (32 registers × 32 bits), no latches, no warnings.

## 2. Data Memory (`rtl/data_memory.v`)

A 256 × 32-bit (1 KiB) byte-addressed data memory with asynchronous read and
synchronous write, with independent read/write enables.

| Port | Dir | Width | Function |
|---|---|---|---|
| `clk` | in | 1 | Clock; stores commit on the rising edge |
| `MemRead` | in | 1 | Read enable (asynchronous read) |
| `MemWrite` | in | 1 | Write enable (synchronous write) |
| `address` | in | 32 | Byte address |
| `write_data` | in | 32 | Data stored when `MemWrite=1` |
| `read_data` | out | 32 | Loaded word when `MemRead=1`, else 0 |

Addressing: byte address → word index = `address[INDEX_WIDTH+1:2]`
(address 0→word 0, 4→word 1, 8→word 2, 64→word 16, 1020→word 255). The low two
bits are the byte offset and are not part of the index.

Documented behavior for non-ideal accesses:
| Case | Write | Read (`read_data`) |
|---|---|---|
| Aligned, in range, enable set | stores word | returns stored word |
| `MemRead=0` | — | `0` |
| `MemWrite=0` | no change | (read path independent) |
| Misaligned (`address[1:0]!=0`) | ignored | `0` |
| Out of range (word index ≥ 256) | ignored | `0` |

Synthesis: 8192 flip-flops (256 × 32), no latches, no warnings. Because the read is
asynchronous, this maps to distributed/LUT RAM rather than synchronous block RAM —
this matches the project's documented single-cycle memory limitation. Converting to
block RAM would require a synchronous-read redesign, which is out of Phase 1 scope.

## 3. Integration readiness

Interface expectations for the eventual top-level (`rv32i_core.v`, owned by the
integration step):

- **Register file ↔ decode/control:** `rs1`, `rs2`, `rd` come from the instruction
  fields; `RegWrite` from the Control Unit (Samiksha); `write_data` from the
  Write-Back MUX (Saumya). `read_data1/2` feed the ALU operand path (Ayush) and the
  store-data / branch-compare paths.
- **Data memory ↔ datapath:** `address` is the ALU result (base + immediate);
  `write_data` is register `read_data2`; `MemRead`/`MemWrite` from the Control Unit;
  `read_data` feeds the Write-Back MUX for `LW`.
- **Clock/reset convention:** both modules use a rising-edge clock, consistent with
  Ankit's PC. Neither has a reset port; if the team standardizes on Ankit's
  synchronous active-high reset, a reset can be added to the register file without
  changing existing ports.

Interface agreements still needed from the team:
1. Confirm signal names `RegWrite`, `MemRead`, `MemWrite` match the Control Unit's outputs.
2. Confirm whether a global reset is required for the register file.
3. Confirm the data-memory depth for integration (256 words here vs. any larger map).
