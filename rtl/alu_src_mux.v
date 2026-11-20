`timescale 1ns/1ps

// =============================================================================
// ALU Source Multiplexer for the single-cycle RV32I processor.
//
// Selects the second operand (operand B) that is fed into the ALU.
//
// In a RISC-V single-cycle datapath, the ALU always receives:
//   - Operand A: register read_data1  (from Register File rs1)
//   - Operand B: THIS MUX output      (either read_data2 or the immediate)
//
// Selection table:
//   ALUSrc | alu_operand_b (selected)
//   -------+-----------------------------------
//     0    | reg_data2    (R-type, BEQ, BNE)
//     1    | imm_ext      (ADDI, LW, SW)
//
// All logic is purely combinational — no clock port is needed.
//
// Author : Saumya
// Module : alu_src_mux
// =============================================================================

module alu_src_mux (
    // Second read-data output from the Register File (rs2 value).
    input  wire [31:0] reg_data2,

    // Sign-extended immediate from the Immediate Generator.
    input  wire [31:0] imm_ext,

    // Control signal from the Main Control Unit.
    //   ALUSrc = 0 -> select reg_data2 (R-type, branch instructions)
    //   ALUSrc = 1 -> select imm_ext   (I-type, S-type instructions)
    input  wire        ALUSrc,

    // The selected 32-bit value delivered to ALU input B.
    output wire [31:0] alu_operand_b
);

    // A simple 2-to-1 MUX implemented as a conditional assignment.
    // This maps directly to a multiplexer in synthesis — no latches.
    assign alu_operand_b = ALUSrc ? imm_ext : reg_data2;

endmodule
