`timescale 1ns/1ps

// =============================================================================
// Write-Back Multiplexer for the single-cycle RV32I processor.
//
// Selects the value that is written back into the Register File destination
// register (rd) at the end of the single-cycle datapath.
//
// For the ten supported instructions the two possible write-back sources are:
//   1. The ALU result  — used by R-type (ADD, SUB, AND, OR, XOR) and
//                        ADDI (arithmetic immediate).
//   2. Data Memory     — used by LW (load word), where the value comes from
//                        memory at the address computed by the ALU.
//
// Selection table:
//   ResultSrc | write_back_data (selected)
//   ----------+-------------------------------------------
//       0     | alu_result    (R-type, ADDI)
//       1     | mem_read_data (LW)
//
// Instructions that do NOT write to rd (SW, BEQ, BNE) will have RegWrite = 0
// from the Control Unit; this MUX output is irrelevant in those cases.
//
// All logic is purely combinational — no clock port is needed.
//
// Author : Saumya
// Module : writeback_mux
// =============================================================================

module writeback_mux (
    // 32-bit result produced by the ALU.
    input  wire [31:0] alu_result,

    // 32-bit word read from Data Memory (LW instruction result).
    input  wire [31:0] mem_read_data,

    // Control signal from the Main Control Unit.
    //   ResultSrc = 0 -> select alu_result    (R-type, ADDI)
    //   ResultSrc = 1 -> select mem_read_data (LW)
    input  wire        ResultSrc,

    // The selected 32-bit value forwarded to the Register File write_data port.
    output wire [31:0] write_back_data
);

    // 2-to-1 MUX: combinational assignment, maps to a multiplexer in synthesis.
    assign write_back_data = ResultSrc ? mem_read_data : alu_result;

endmodule
