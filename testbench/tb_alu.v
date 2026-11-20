`timescale 1ns/1ps

module tb_alu;
    reg  [31:0] a, b;
    reg  [2:0]  alu_control;
    wire [31:0] result;
    wire        zero;
    integer tests;

    alu dut (.a(a), .b(b), .alu_control(alu_control),
             .result(result), .zero(zero));

    task check;
        input [2:0]  op;
        input [31:0] lhs, rhs, expected;
        input        expected_zero;
        begin
            alu_control = op;
            a = lhs;
            b = rhs;
            #1;
            if (result !== expected || zero !== expected_zero) begin
                $display("FAIL: op=%b a=%h b=%h result=%h zero=%b expected=%h/%b",
                         op, lhs, rhs, result, zero, expected, expected_zero);
                $fatal(1);
            end
            tests = tests + 1;
        end
    endtask

    initial begin
        tests = 0;
        $dumpfile("build/tb_alu.vcd");
        $dumpvars(0, tb_alu);

        check(3'b000, 32'd7, 32'd5, 32'd12, 1'b0);
        check(3'b000, -32'sd7, 32'd5, -32'sd2, 1'b0);
        check(3'b000, 32'h7fffffff, 32'd1, 32'h80000000, 1'b0);
        check(3'b000, 32'hffffffff, 32'd1, 32'h00000000, 1'b1);
        check(3'b000, 32'h80000000, 32'h80000000, 32'h00000000, 1'b1);

        check(3'b001, 32'd12, 32'd5, 32'd7, 1'b0);
        check(3'b001, 32'd5, 32'd12, -32'sd7, 1'b0);
        check(3'b001, -32'sd7, -32'sd7, 32'd0, 1'b1);
        check(3'b001, 32'h80000000, 32'd1, 32'h7fffffff, 1'b0);
        check(3'b001, 32'd0, 32'd1, 32'hffffffff, 1'b0);

        check(3'b010, 32'hf0f0a5a5, 32'h0ff05a5a, 32'h00f00000, 1'b0);
        check(3'b010, 32'hffffffff, 32'h00000000, 32'd0, 1'b1);
        check(3'b011, 32'hf0f00000, 32'h00000f0f, 32'hf0f00f0f, 1'b0);
        check(3'b011, 32'd0, 32'd0, 32'd0, 1'b1);
        check(3'b100, 32'hffff0000, 32'h0f0f0f0f, 32'hf0f00f0f, 1'b0);
        check(3'b100, 32'hdeadbeef, 32'hdeadbeef, 32'd0, 1'b1);
        check(3'b111, 32'd1, 32'd2, 32'd0, 1'b1);

        $display("ALU TEST PASSED (%0d cases)", tests);
        $finish;
    end
endmodule
