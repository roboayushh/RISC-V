`timescale 1ns/1ps

// 256 x 32-bit data memory for the single-cycle RV32I processor.
//
// Capacity: 256 words x 32 bits = 8192 bits = 1 KiB.
// - Byte-addressed interface: byte address -> word index is address[.. :2]
//   (address 0 -> word 0, 4 -> word 1, 8 -> word 2, 64 -> word 16, ...).
// - Asynchronous (combinational) read, gated by MemRead.
// - Synchronous write on the rising clock edge, gated by MemWrite.
// - Separate read and write enables, to match the LW/SW datapath.
//
// Deterministic / documented behavior for non-ideal accesses:
// - Misaligned address (address[1:0] != 0): no write occurs; read returns 0.
// - Out-of-range address (word index >= DEPTH): no write occurs; read returns 0.
// - When MemRead = 0: read_data is 0 (no stale/undefined value is driven).
//
// Synthesis implication: the initial block below zeroes memory for simulation.
// On an FPGA this maps to initialized RAM where supported; otherwise initial
// contents should not be relied upon and must be written before being read.
module data_memory #(
    parameter DEPTH = 256,
    parameter DATA_WIDTH = 32
) (
    input  wire                  clk,
    input  wire                  MemRead,     // Read  enable (asynchronous read)
    input  wire                  MemWrite,    // Write enable (synchronous write)
    input  wire [31:0]           address,     // Byte address
    input  wire [DATA_WIDTH-1:0] write_data,  // Data to store when MemWrite = 1
    output reg  [DATA_WIDTH-1:0] read_data    // Loaded data when MemRead = 1, else 0
);

    localparam INDEX_WIDTH = $clog2(DEPTH); // Word-index width (8 bits for DEPTH = 256).

    reg [DATA_WIDTH-1:0] memory [0:DEPTH-1];
    integer i;

    // Word index derived from the byte address (drop the 2 byte-offset bits).
    wire                   aligned   = (address[1:0] == 2'b00);
    wire                   in_range  = (address[31:2] < DEPTH);
    wire [INDEX_WIDTH-1:0] word_index = address[INDEX_WIDTH+1:2];

    // Deterministic initialization for simulation.
    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            memory[i] = {DATA_WIDTH{1'b0}};
    end

    // Asynchronous read: only when enabled, aligned, and in range; else 0.
    always @(*) begin
        if (MemRead && aligned && in_range)
            read_data = memory[word_index];
        else
            read_data = {DATA_WIDTH{1'b0}};
    end

    // Synchronous write: only when enabled, aligned, and in range.
    always @(posedge clk) begin
        if (MemWrite && aligned && in_range)
            memory[word_index] <= write_data;
    end

endmodule
