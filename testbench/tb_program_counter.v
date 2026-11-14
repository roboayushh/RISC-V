`timescale 1ns/1ps

module tb_program_counter;

    reg clk;
    reg reset;
    reg [31:0] next_pc;
    wire [31:0] pc;
    integer errors;

    program_counter dut (
        .clk     (clk),
        .reset   (reset),
        .next_pc (next_pc),
        .pc      (pc)
    );

    always #5 clk = ~clk;

    task check_pc;
        input [31:0] expected_pc;
        begin
            if (pc !== expected_pc) begin
                $display("FAIL: expected PC=0x%08h, got PC=0x%08h", expected_pc, pc);
                errors = errors + 1;
            end else begin
                $display("PASS: PC=0x%08h", pc);
            end
        end
    endtask

    initial begin
        $dumpfile("build/tb_program_counter.vcd");
        $dumpvars(0, tb_program_counter);
        clk = 1'b0;
        reset = 1'b1;
        next_pc = 32'h00000000;
        errors = 0;

        // Synchronous reset is sampled on the rising clock edge.
        repeat (2) @(posedge clk);
        #1;
        check_pc(32'h00000000);

        // Check sequential next-PC values (PC + 4 is supplied by the core).
        @(negedge clk);
        reset = 1'b0;
        next_pc = 32'h00000004;
        @(posedge clk);
        #1;
        check_pc(32'h00000004);

        @(negedge clk);
        next_pc = 32'h00000008;
        @(posedge clk);
        #1;
        check_pc(32'h00000008);

        // Check that the PC can accept a non-sequential target in later phases.
        @(negedge clk);
        next_pc = 32'h00000100;
        @(posedge clk);
        #1;
        check_pc(32'h00000100);

        // Check reset after the PC has advanced.
        @(negedge clk);
        reset = 1'b1;
        @(posedge clk);
        #1;
        check_pc(32'h00000000);

        if (errors == 0)
            $display("\nPROGRAM COUNTER TEST PASSED");
        else
            $display("\nPROGRAM COUNTER TEST FAILED: %0d error(s)", errors);

        $finish;
    end

endmodule
