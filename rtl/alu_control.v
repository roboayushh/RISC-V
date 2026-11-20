`timescale 1ns/1ps

// ALUOp: 00 = ADD (ADDI/LW/SW), 01 = SUB (BEQ/BNE),
// 10 = decode RV32I R-type funct3 and instruction[30].
// Unsupported codes produce 111, which makes alu.result zero.
module alu_control (
    input  wire [1:0] alu_op,
    input  wire [2:0] funct3,
    input  wire       funct7_bit5,
    output reg  [2:0] operation
);
    always @(*) begin
        operation = 3'b111;
        case (alu_op)
            2'b00: operation = 3'b000;
            2'b01: operation = 3'b001;
            2'b10: begin
                case (funct3)
                    3'b000: operation = funct7_bit5 ? 3'b001 : 3'b000;
                    3'b111: if (!funct7_bit5) operation = 3'b010;
                    3'b110: if (!funct7_bit5) operation = 3'b011;
                    3'b100: if (!funct7_bit5) operation = 3'b100;
                    default: operation = 3'b111;
                endcase
            end
            default: operation = 3'b111;
        endcase
    end
endmodule
