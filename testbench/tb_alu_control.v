`timescale 1ns/1ps

module tb_alu_control;
    reg  [1:0] alu_op;
    reg  [2:0] funct3;
    reg        funct7_bit5;
    wire [2:0] operation;
    integer tests;

    alu_control dut (.alu_op(alu_op), .funct3(funct3),
                     .funct7_bit5(funct7_bit5), .operation(operation));

    task check;
        input [1:0] op;
        input [2:0] f3;
        input       f7b5;
        input [2:0] expected;
        begin
            alu_op = op;
            funct3 = f3;
            funct7_bit5 = f7b5;
            #1;
            if (operation !== expected) begin
                $display("FAIL: alu_op=%b funct3=%b funct7_bit5=%b got=%b expected=%b",
                         op, f3, f7b5, operation, expected);
                $fatal(1);
            end
            tests = tests + 1;
        end
    endtask

    initial begin
        tests = 0;
        $dumpfile("build/tb_alu_control.vcd");
        $dumpvars(0, tb_alu_control);

        check(2'b00, 3'b000, 1'b0, 3'b000); // address / ADDI
        check(2'b00, 3'b111, 1'b1, 3'b000); // function ignored
        check(2'b01, 3'b000, 1'b0, 3'b001); // BEQ/BNE compare
        check(2'b01, 3'b111, 1'b1, 3'b001); // function ignored
        check(2'b10, 3'b000, 1'b0, 3'b000); // ADD
        check(2'b10, 3'b000, 1'b1, 3'b001); // SUB
        check(2'b10, 3'b111, 1'b0, 3'b010); // AND
        check(2'b10, 3'b110, 1'b0, 3'b011); // OR
        check(2'b10, 3'b100, 1'b0, 3'b100); // XOR
        check(2'b10, 3'b111, 1'b1, 3'b111); // unsupported R-type
        check(2'b10, 3'b110, 1'b1, 3'b111);
        check(2'b10, 3'b100, 1'b1, 3'b111);
        check(2'b10, 3'b010, 1'b0, 3'b111);
        check(2'b11, 3'b000, 1'b0, 3'b111); // unsupported ALUOp

        $display("ALU CONTROL TEST PASSED (%0d cases)", tests);
        $finish;
    end
endmodule
