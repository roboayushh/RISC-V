`timescale 1ns/1ps

module control_unit (
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire [6:0] funct7,
    output reg        RegWrite,
    output reg        ALUSrc,
    output reg        MemRead,
    output reg        MemWrite,
    output reg        ResultSrc,
    output reg        Branch,
    output reg  [1:0] ALUOp,
    output reg  [1:0] ImmSrc
);
    localparam [6:0] OP_RTYPE = 7'b0110011;
    localparam [6:0] OP_IMM   = 7'b0010011;

    always @(*) begin
        // Safe defaults for unsupported encodings.
        RegWrite  = 1'b0;
        ALUSrc    = 1'b0;
        MemRead   = 1'b0;
        MemWrite  = 1'b0;
        ResultSrc = 1'b0;
        Branch    = 1'b0;
        ALUOp     = 2'b11;
        ImmSrc    = 2'b11;

        case (opcode)
            OP_RTYPE: begin
                case ({funct7, funct3})
                    10'b0000000_000, // ADD
                    10'b0100000_000, // SUB
                    10'b0000000_111, // AND
                    10'b0000000_110, // OR
                    10'b0000000_100: begin // XOR
                        RegWrite = 1'b1;
                        ALUOp    = 2'b10;
                    end
                    default: begin end
                endcase
            end
            OP_IMM: begin
                if (funct3 == 3'b000) begin // ADDI
                    RegWrite = 1'b1;
                    ALUSrc   = 1'b1;
                    ALUOp    = 2'b00;
                    ImmSrc   = 2'b00;
                end
            end
            default: begin end
        endcase
    end
endmodule
