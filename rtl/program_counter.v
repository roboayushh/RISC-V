`timescale 1ns/1ps

// 32-bit Program Counter for the RV32I processor.
// Reset is synchronous and active-high.
module program_counter #(
    parameter RESET_PC = 32'h00000000
) (
    input  wire        clk,
    input  wire        reset,
    input  wire [31:0] next_pc,
    output reg  [31:0] pc
);

    always @(posedge clk) begin
        if (reset)
            pc <= RESET_PC;
        else
            pc <= next_pc;
    end

endmodule
