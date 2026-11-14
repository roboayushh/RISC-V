`timescale 1ns/1ps

module tb_rv32i_core;

    reg clk;
    reg reset;
    wire [31:0] pc;
    wire [31:0] instruction;
    integer errors;

    rv32i_core #(
        .IMEM_DEPTH     (4),
        .IMEM_INIT_FILE ("programs/test_program.hex")
    ) dut (
        .clk         (clk),
        .reset       (reset),
        .pc          (pc),
        .instruction (instruction)
    );

    always #5 clk = ~clk;

    task check_fetch;
        input [31:0] expected_pc;
        input [31:0] expected_instruction;
        begin
            #1;
            if ((pc !== expected_pc) || (instruction !== expected_instruction)) begin
                $display("FAIL: expected PC=0x%08h INST=0x%08h; got PC=0x%08h INST=0x%08h",
                         expected_pc, expected_instruction, pc, instruction);
                errors = errors + 1;
            end else begin
                $display("PASS: PC=0x%08h INST=0x%08h", pc, instruction);
            end
        end
    endtask

    initial begin
        $dumpfile("build/tb_rv32i_core.vcd");
        $dumpvars(0, tb_rv32i_core);
        clk = 1'b0;
        reset = 1'b1;
        errors = 0;

        repeat (2) @(posedge clk);
        check_fetch(32'h00000000, 32'h00500093);

        @(negedge clk);
        reset = 1'b0;
        @(posedge clk);
        check_fetch(32'h00000004, 32'h00A00113);

        @(posedge clk);
        check_fetch(32'h00000008, 32'h002081B3);

        @(posedge clk);
        check_fetch(32'h0000000C, 32'h00302023);

        @(posedge clk);
        check_fetch(32'h00000010, 32'h00000013);

        if (errors == 0)
            $display("\nRV32I FETCH-PATH TEST PASSED");
        else
            $display("\nRV32I FETCH-PATH TEST FAILED: %0d error(s)", errors);

        $finish;
    end

endmodule
