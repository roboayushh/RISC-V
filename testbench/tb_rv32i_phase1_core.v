`timescale 1ns/1ps

module tb_rv32i_phase1_core;
    reg clk;
    reg reset;
    wire [31:0] pc;
    wire [31:0] instruction;

    rv32i_phase1_core dut (
        .clk(clk),
        .reset(reset),
        .pc(pc),
        .instruction(instruction)
    );

    always #5 clk = ~clk;

    task check_register;
        input [4:0] index;
        input [31:0] expected;
        begin
            if (dut.register_file_unit.registers[index] !== expected)
                $fatal(1, "x%0d: expected %08h, got %08h",
                       index, expected, dut.register_file_unit.registers[index]);
        end
    endtask

    task check_step;
        input [31:0] expected_pc;
        input [4:0]  index;
        input        expected_write;
        input [31:0] expected_value;
        begin
            if (pc !== expected_pc)
                $fatal(1, "Expected PC=%08h, got %08h", expected_pc, pc);
            if (dut.write_enable !== expected_write)
                $fatal(1, "PC=%08h: expected write enable %b, got %b",
                       pc, expected_write, dut.write_enable);
            if (expected_write && (dut.rd !== index))
                $fatal(1, "PC=%08h: expected destination x%0d, got x%0d", pc, index, dut.rd);
            @(posedge clk);
            #1;
            check_register(index, expected_value);
            $display("PASS: PC=%08h x%0d=%0d", expected_pc, index, expected_value);
        end
    endtask

    initial begin
        $dumpfile("build/tb_rv32i_phase1_core.vcd");
        $dumpvars(0, tb_rv32i_phase1_core);

        clk = 1'b0;
        reset = 1'b1;
        repeat (2) @(posedge clk);
        #1;
        if (pc !== 32'd0)
            $fatal(1, "Reset PC must be zero, got %08h", pc);
        if (dut.write_enable !== 1'b0)
            $fatal(1, "Register write enabled during reset");
        check_register(5'd1, 32'd0);

        @(negedge clk);
        reset = 1'b0;
        #1;

        check_step(32'd0,  5'd1, 1'b1, 32'd10); // ADDI
        check_step(32'd4,  5'd2, 1'b1, 32'd20); // ADDI
        check_step(32'd8,  5'd3, 1'b1, 32'd30); // ADD
        check_step(32'd12, 5'd4, 1'b1, 32'd10); // SUB
        check_step(32'd16, 5'd5, 1'b1, 32'd0);  // AND
        check_step(32'd20, 5'd6, 1'b1, 32'd30); // OR
        check_step(32'd24, 5'd7, 1'b1, 32'd30); // XOR
        check_step(32'd28, 5'd0, 1'b1, 32'd0);  // Ignore write to x0
        check_step(32'd32, 5'd8, 1'b1, 32'd18); // Negative ADDI
        check_step(32'd36, 5'd8, 1'b0, 32'd18); // LW leaves x8 unchanged
        check_step(32'd40, 5'd8, 1'b0, 32'd18); // MUL leaves x8 unchanged

        check_step(32'd44, 5'd9,  1'b1, 32'd16); // Nonzero AND
        check_step(32'd48, 5'd10, 1'b1, 32'd22); // OR of overlapping operands
        check_step(32'd52, 5'd11, 1'b1, 32'd6);  // XOR differs from OR

        if ((pc !== 32'd56) || (instruction !== 32'h00000013))
            $fatal(1, "Expected NOP at end of program, PC=%08h INST=%08h",
                   pc, instruction);

        $display("PHASE 1 ARITHMETIC TEST PASSED");
        $finish;
    end
endmodule
