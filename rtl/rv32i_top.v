`timescale 1ns/1ps

// =============================================================================
// rv32i_top.v — Top-Level Wrapper for the Single-Cycle RV32I Processor
//
// Author : Ankit
// Phase  : 2 — Complete Processor Integration and Top-Level Design
//
// Description:
//   External top-level module that wraps rv32i_core and exposes a clean
//   interface for simulation or FPGA deployment. This is the single
//   entry-point that instantiates the entire processor.
//
// Features:
//   - Parameterized instruction memory depth and program file
//   - Parameterized data memory depth
//   - Exposes PC, current instruction, and halt status for observability
//   - Completion observation: flags two consecutive identical PC samples
//     when a program reaches its terminal branch-to-self
//
// Port summary:
//   clk         — System clock (rising-edge active)
//   reset       — Synchronous active-high reset
//   pc_out      — Current program counter value
//   instr_out   — Current instruction being executed
//   halted      — High when two consecutive sampled PC values match
// =============================================================================

module rv32i_top #(
    parameter IMEM_DEPTH     = 22,
    parameter IMEM_INIT_FILE = "programs/integration.hex",
    parameter DMEM_DEPTH     = 256,
    parameter IMEM_WORDS = IMEM_DEPTH
) (
    input  wire        clk,
    input  wire        reset,
    output wire [31:0] pc_out,
    output wire [31:0] instr_out,
    output reg         halted
);

    // =========================================================================
    // Processor core instantiation
    // =========================================================================

    wire [31:0] pc_wire;
    wire [31:0] instr_wire;

    rv32i_core #(
        .IMEM_DEPTH     (IMEM_DEPTH),
        .IMEM_WORDS     (IMEM_WORDS),
        .IMEM_INIT_FILE (IMEM_INIT_FILE),
        .DMEM_DEPTH     (DMEM_DEPTH)
    ) u_core (
        .clk         (clk),
        .reset       (reset),
        .pc          (pc_wire),
        .instruction (instr_wire)
    );

    assign pc_out    = pc_wire;
    assign instr_out = instr_wire;

    // =========================================================================
    // Halt detection
    // =========================================================================
    // The assembly programs use BEQ x0, x0, 0 as a completion marker.
    // Two consecutive matching PC samples raise this observation flag.
    // The core continues executing the self-branch. NOPs advance PC by four,
    // and a loop through several different PCs keeps this flag low.
    //
    // This is useful for testbenches: they can wait until `halted` goes high
    // rather than counting a fixed number of clock cycles.
    // =========================================================================

    reg [31:0] pc_prev;

    always @(posedge clk) begin
        if (reset) begin
            halted  <= 1'b0;
            pc_prev <= 32'hFFFFFFFF;  // Impossible initial value
        end else begin
            if (pc_wire == pc_prev)
                halted <= 1'b1;
            else
                halted <= 1'b0;
            pc_prev <= pc_wire;
        end
    end

endmodule
