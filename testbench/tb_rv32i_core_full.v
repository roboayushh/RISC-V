`timescale 1ns/1ps

// Self-checking testbench for the full single-cycle RV32I core.
// Runs programs/full_demo.hex, which exercises arithmetic, logic, SW/LW, and
// both branch types (BEQ taken, BNE taken), then checks the final register and
// data-memory state.
module tb_rv32i_core_full;

    reg         clk;
    reg         reset;
    wire [31:0] pc;
    wire [31:0] instruction;
    integer     errors;

    rv32i_core_full #(
        .IMEM_DEPTH     (11),
        .IMEM_INIT_FILE ("programs/full_demo.hex"),
        .DMEM_DEPTH     (256)
    ) dut (
        .clk         (clk),
        .reset       (reset),
        .pc          (pc),
        .instruction (instruction)
    );

    always #5 clk = ~clk;

    // Check an architectural register against an expected value.
    task check_reg;
        input [4:0]  idx;
        input [31:0] expected;
        reg   [31:0] actual;
        begin
            actual = dut.rf.registers[idx];
            if (idx == 5'd0) actual = 32'b0; // x0 always reads zero
            if (actual !== expected) begin
                $display("FAIL: x%0d expected=%0d (0x%08h) got=%0d (0x%08h)",
                         idx, expected, expected, actual, actual);
                errors = errors + 1;
            end else begin
                $display("PASS: x%0d = %0d", idx, actual);
            end
        end
    endtask

    // Check a data-memory word (by word index) against an expected value.
    task check_mem;
        input integer word_index;
        input [31:0]  expected;
        reg   [31:0]  actual;
        begin
            actual = dut.dmem.memory[word_index];
            if (actual !== expected) begin
                $display("FAIL: mem[%0d] expected=%0d got=%0d",
                         word_index, expected, actual);
                errors = errors + 1;
            end else begin
                $display("PASS: mem[%0d] = %0d", word_index, actual);
            end
        end
    endtask

    initial begin
        $dumpfile("build/tb_rv32i_core_full.vcd");
        $dumpvars(0, tb_rv32i_core_full);
        clk = 1'b0; reset = 1'b1; errors = 0;

        // Hold reset for two edges, then run the program.
        repeat (2) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        // Allow all instructions (including branch redirects) to execute.
        repeat (20) @(posedge clk);

        $display("\n--- Final architectural state ---");
        check_reg(5'd1,  32'd10);  // ADDI x1,x0,10
        check_reg(5'd2,  32'd20);  // ADDI x2,x0,20
        check_reg(5'd3,  32'd30);  // ADD  x3,x1,x2
        check_reg(5'd4,  32'd30);  // LW   x4 <- mem[0] (stored x3)
        check_reg(5'd5,  32'd0);   // ADDI x5,99 SKIPPED by BEQ-taken
        check_reg(5'd6,  32'd7);   // ADDI x6,x0,7  (BEQ target)
        check_reg(5'd7,  32'd0);   // ADDI x7,88 SKIPPED by BNE-taken
        check_reg(5'd8,  32'd5);   // ADDI x8,x0,5  (BNE target)
        check_mem(0,     32'd30);  // SW stored x3 (=30) at byte addr 0

        if (errors == 0)
            $display("\nFULL RV32I CPU TEST PASSED (10-instruction datapath)");
        else
            $display("\nFULL RV32I CPU TEST FAILED: %0d error(s)", errors);

        $finish;
    end

endmodule
