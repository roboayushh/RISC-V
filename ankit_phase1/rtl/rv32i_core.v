`timescale 1ns/1ps

// Phase-1 fetch-path scaffold for the single-cycle RV32I processor.
// It connects the Program Counter to Instruction Memory and advances
// sequentially by 4 bytes. Later integration will replace pc_plus4 with
// the next-PC selection logic for branches and jumps.
module rv32i_core #(
    parameter IMEM_DEPTH = 256,
    parameter IMEM_INIT_FILE = "programs/test_program.hex"
) (
    input  wire        clk,
    input  wire        reset,
    output wire [31:0] pc,
    output wire [31:0] instruction
);

    wire [31:0] pc_plus4;

    assign pc_plus4 = pc + 32'd4;

    program_counter pc_unit (
        .clk     (clk),
        .reset   (reset),
        .next_pc (pc_plus4),
        .pc      (pc)
    );

    instruction_memory #(
        .DEPTH     (IMEM_DEPTH),
        .INIT_FILE (IMEM_INIT_FILE)
    ) instruction_memory_unit (
        .address     (pc),
        .instruction (instruction)
    );

endmodule
