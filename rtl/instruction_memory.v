`timescale 1ns/1ps

// Read-only instruction memory for 32-bit RV32I instructions.
// Addresses are byte addresses. Each instruction occupies 4 bytes,
// so a word-aligned address selects memory word address[31:2].
module instruction_memory #(
    parameter DEPTH = 256,
    parameter INIT_FILE = "programs/test_program.hex"
) (
    input  wire [31:0] address,
    output reg  [31:0] instruction
);

    localparam NOP = 32'h00000013; // ADDI x0, x0, 0
    localparam ADDR_WIDTH = $clog2(DEPTH); // Word-index width for a DEPTH-entry memory.

    reg [31:0] memory [0:DEPTH-1];
    integer i;

    // Initialize unused locations to NOP, then load the program image.
    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            memory[i] = NOP;

        if (INIT_FILE != "")
            $readmemh(INIT_FILE, memory);
    end

    // Combinational read: instruction is available from the current PC.
    always @(*) begin
        if (address[1:0] != 2'b00)
            instruction = NOP; // RV32I instructions must be 4-byte aligned here.
        else if (address[31:2] < DEPTH)
            // Sized word index; the range check above guarantees the upper
            // address bits are zero here, so the value is unchanged.
            instruction = memory[address[ADDR_WIDTH+1:2]];
        else
            instruction = NOP; // Deterministic result for out-of-range fetches.
    end

endmodule
