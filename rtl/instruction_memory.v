`timescale 1ns/1ps

// Read-only instruction memory for 32-bit RV32I instructions.
// Addresses are byte addresses. Each instruction occupies 4 bytes,
// so a word-aligned address selects memory word address[31:2].
module instruction_memory #(
    parameter DEPTH = 256,
    parameter INIT_FILE = "programs/test_program.hex",
    parameter INIT_WORDS = (DEPTH < 4) ? DEPTH : 4
) (
    input  wire [31:0] address,
    output reg  [31:0] instruction
);

    localparam NOP = 32'h00000013; // ADDI x0, x0, 0
    // A one-word memory still needs a nonzero index width.
    localparam ADDR_WIDTH = (DEPTH > 1) ? $clog2(DEPTH) : 1;

    reg [31:0] memory [0:DEPTH-1];
    integer i;

    wire [ADDR_WIDTH-1:0] word_index =
        (DEPTH == 1) ? {ADDR_WIDTH{1'b0}} : address[ADDR_WIDTH+1:2];
    wire [31:0] selected_word = memory[word_index];

    // INIT_WORDS is the number of words in INIT_FILE, independent of capacity.
    // Never expose uninitialized synthesis locations as executable instructions.
    // For an empty image the entire ROM is NOP in both simulation and synthesis.
    initial begin
        if (INIT_FILE == "") begin
            for (i = 0; i < DEPTH; i = i + 1) memory[i] = NOP;
        end else begin
            $readmemh(INIT_FILE, memory, 0, INIT_WORDS-1);
        end
    end

    // Combinational read: instruction is available from the current PC.
    always @(*) begin
        if (address[1:0] != 2'b00)
            instruction = NOP; // RV32I instructions must be 4-byte aligned here.
        else if ({2'b00, address[31:2]} < DEPTH)
            instruction = (INIT_FILE != "" && {2'b00, address[31:2]} >= INIT_WORDS)
                ? NOP : selected_word;
        else
            instruction = NOP; // Deterministic result for out-of-range fetches.
    end

endmodule
