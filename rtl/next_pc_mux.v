`timescale 1ns/1ps

// =============================================================================
// Next-PC Multiplexer for the single-cycle RV32I processor.
//
// Selects the address that the Program Counter will load on the next rising
// clock edge.
//
// In the single-cycle RV32I datapath two PC sources exist:
//   1. PC + 4         — the next sequential instruction address.
//   2. BranchTarget   — the branch destination address (PC + B-type immediate).
//
// The branch decision signal (PCSrc) is computed OUTSIDE this module by the
// branch decision logic (which checks the ALU zero flag and the BEQ/BNE opcode).
// This MUX only routes the already-decided next address.
//
// Selection table:
//   PCSrc | next_pc (selected)
//   ------+---------------------
//     0   | pc_plus4      (sequential, taken when branch is not taken)
//     1   | branch_target (branch taken)
//
// All logic is purely combinational — no clock port is needed.
//
// Author : Saumya
// Module : next_pc_mux
// =============================================================================

module next_pc_mux (
    // The sequential next-PC value (current PC + 4).
    // Calculated as a simple 32-bit add in rv32i_core.v.
    input  wire [31:0] pc_plus4,

    // The branch target address (current PC + sign-extended B-type immediate).
    // Calculated by branch_target.v.
    input  wire [31:0] branch_target,

    // Branch-taken decision signal.  Driven by branch decision logic, NOT by
    // this module.
    //   PCSrc = 0 -> select pc_plus4      (branch not taken, or non-branch)
    //   PCSrc = 1 -> select branch_target (branch taken)
    input  wire        PCSrc,

    // The address loaded into the Program Counter on the next clock edge.
    output wire [31:0] next_pc
);

    // 2-to-1 MUX: simple conditional assignment.
    assign next_pc = PCSrc ? branch_target : pc_plus4;

endmodule
