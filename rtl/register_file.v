`timescale 1ns/1ps

// 32 x 32-bit register file for the single-cycle RV32I processor.
//
// - Two independent asynchronous (combinational) read ports.
// - One synchronous write port, enabled by RegWrite on the rising clock edge.
// - Architectural register x0 is hardwired to zero: it always reads as zero and
//   any write targeting x0 is ignored.
//
// There is no hardware reset port (matching the agreed Phase 1 interface). For
// deterministic simulation, all registers are initialized to zero in an initial
// block. Synthesis implication: on an FPGA without this initial value, general
// registers power up undefined; correct RV32I programs always write a register
// before reading it, and x0 is constant regardless. If the team later wants a
// global synchronous reset, it can be added without changing the read/write ports.
module register_file #(
    parameter REG_COUNT = 32,
    parameter REG_WIDTH = 32,
    parameter ADDR_WIDTH = 5
) (
    input  wire                  clk,
    input  wire [ADDR_WIDTH-1:0] rs1,        // First  read address
    input  wire [ADDR_WIDTH-1:0] rs2,        // Second read address
    input  wire [ADDR_WIDTH-1:0] rd,         // Write  address
    input  wire [REG_WIDTH-1:0]  write_data, // Data to write when RegWrite = 1
    input  wire                  RegWrite,    // Write enable
    output wire [REG_WIDTH-1:0]  read_data1, // Value of register rs1 (0 if rs1 = x0)
    output wire [REG_WIDTH-1:0]  read_data2  // Value of register rs2 (0 if rs2 = x0)
);

    reg [REG_WIDTH-1:0] registers [0:REG_COUNT-1];
    integer i;

    // Deterministic initialization for simulation.
    initial begin
        for (i = 0; i < REG_COUNT; i = i + 1)
            registers[i] = {REG_WIDTH{1'b0}};
    end

    // Asynchronous reads. x0 (address 0) always reads as zero.
    assign read_data1 = (rs1 == {ADDR_WIDTH{1'b0}}) ? {REG_WIDTH{1'b0}} : registers[rs1];
    assign read_data2 = (rs2 == {ADDR_WIDTH{1'b0}}) ? {REG_WIDTH{1'b0}} : registers[rs2];

    // Synchronous write. Writes to x0 are ignored so x0 stays zero.
    always @(posedge clk) begin
        if (RegWrite && (rd != {ADDR_WIDTH{1'b0}}))
            registers[rd] <= write_data;
    end

endmodule
