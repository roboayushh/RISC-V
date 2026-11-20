`timescale 1ns/1ps

// =============================================================================
// Branch Target Calculator for the single-cycle RV32I processor.
//
// Computes the destination address for a conditional branch instruction
// (BEQ or BNE):
//
//   BranchTarget = PC + imm_ext
//
// where imm_ext is the sign-extended B-type immediate produced by
// immediate_generator.v.
//
// Key design notes:
//   1. The B-type immediate already has bit 0 = 0 (enforced by the Immediate
//      Generator), so NO additional left-shift is needed here.  The RISC-V
//      spec encodes the branch offset as a multiple of 2 by omitting bit 0
//      from the instruction field and placing it as 1'b0 in imm_ext[0].
//
//   2. This module does NOT decide whether the branch is taken or not.  The
//      BEQ/BNE comparison is performed by the ALU (using SUB), and the zero
//      flag combined with the instruction opcode determines PCSrc in the
//      Control/Branch-Decision logic (Samiksha's responsibility).
//
//   3. The addition is 32-bit modular — upper bits that overflow wrap around.
//      This matches the RV32I specification for branch targets.
//
//   4. Pure combinational logic — no clock port.
//
// Author : Saumya
// Module : branch_target
// =============================================================================

module branch_target (
    // Current value of the Program Counter (the address of the branch
    // instruction itself, not PC+4).
    input  wire [31:0] pc,

    // Sign-extended B-type immediate from immediate_generator.v.
    // imm_ext[0] is guaranteed to be 0 (even-byte alignment).
    input  wire [31:0] imm_ext,

    // Computed branch destination address: PC + imm_ext.
    output wire [31:0] branch_target_addr
);

    // Combinational 32-bit addition.  Synthesis produces an adder here.
    assign branch_target_addr = pc + imm_ext;

endmodule
