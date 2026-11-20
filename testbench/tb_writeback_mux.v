`timescale 1ns/1ps

// =============================================================================
// Self-checking testbench for writeback_mux.v
//
// Tests both selector values (ALU result and memory read data) with distinct
// data patterns so an incorrect selection is unambiguously detectable.
//
// Author : Saumya
// =============================================================================

module tb_writeback_mux;

    // -------------------------------------------------------------------------
    // DUT connections
    // -------------------------------------------------------------------------
    reg  [31:0] alu_result;
    reg  [31:0] mem_read_data;
    reg         ResultSrc;
    wire [31:0] write_back_data;

    writeback_mux dut (
        .alu_result     (alu_result),
        .mem_read_data  (mem_read_data),
        .ResultSrc      (ResultSrc),
        .write_back_data(write_back_data)
    );

    // -------------------------------------------------------------------------
    // Book-keeping
    // -------------------------------------------------------------------------
    integer errors;
    integer tests;

    // -------------------------------------------------------------------------
    // Helper task
    // -------------------------------------------------------------------------
    task check;
        input [31:0] alu;    // alu_result value
        input [31:0] mem;    // mem_read_data value
        input        sel;    // ResultSrc selector
        input [31:0] expected;
        begin
            alu_result    = alu;
            mem_read_data = mem;
            ResultSrc     = sel;
            #1;
            if (write_back_data !== expected) begin
                $display("FAIL: ResultSrc=%b alu=0x%08h mem=0x%08h expected=0x%08h got=0x%08h",
                         sel, alu, mem, expected, write_back_data);
                errors = errors + 1;
            end else begin
                $display("PASS: ResultSrc=%b -> write_back_data=0x%08h (correct)",
                         sel, write_back_data);
            end
            tests = tests + 1;
        end
    endtask

    // =========================================================================
    // Simulation body
    // =========================================================================
    initial begin
        $dumpfile("build/tb_writeback_mux.vcd");
        $dumpvars(0, tb_writeback_mux);

        errors = 0;
        tests  = 0;

        // =====================================================================
        // ResultSrc = 0: select alu_result  (R-type, ADDI)
        // =====================================================================

        // Typical ADD result
        check(32'h0000000F, 32'hDEADBEEF, 1'b0, 32'h0000000F);

        // ALU result = 0 (after subtraction or XOR of equal values)
        check(32'h00000000, 32'hCAFEBABE, 1'b0, 32'h00000000);

        // ALU result = max 32-bit positive
        check(32'h7FFFFFFF, 32'h00000001, 1'b0, 32'h7FFFFFFF);

        // ALU result = all ones
        check(32'hFFFFFFFF, 32'h11111111, 1'b0, 32'hFFFFFFFF);

        // =====================================================================
        // ResultSrc = 1: select mem_read_data  (LW)
        // =====================================================================

        // Typical loaded word
        check(32'h0000000A, 32'hCAFEBABE, 1'b1, 32'hCAFEBABE);

        // Memory data = 0
        check(32'h00000005, 32'h00000000, 1'b1, 32'h00000000);

        // Memory data = negative
        check(32'h00000001, 32'hFFFFFFFF, 1'b1, 32'hFFFFFFFF);

        // Memory data = pattern value
        check(32'h55555555, 32'hAAAAAAAA, 1'b1, 32'hAAAAAAAA);

        // =====================================================================
        // Switch check: toggling ResultSrc produces the correct result
        // =====================================================================
        alu_result    = 32'h11111111;
        mem_read_data = 32'h22222222;
        ResultSrc = 1'b0; #1;
        if (write_back_data !== 32'h11111111) begin
            $display("FAIL [switch]: ResultSrc=0 expected 0x11111111 got 0x%08h", write_back_data);
            errors = errors + 1;
        end else
            $display("PASS [switch]: ResultSrc=0 -> 0x%08h", write_back_data);
        tests = tests + 1;

        ResultSrc = 1'b1; #1;
        if (write_back_data !== 32'h22222222) begin
            $display("FAIL [switch]: ResultSrc=1 expected 0x22222222 got 0x%08h", write_back_data);
            errors = errors + 1;
        end else
            $display("PASS [switch]: ResultSrc=1 -> 0x%08h", write_back_data);
        tests = tests + 1;

        // =====================================================================
        // Summary
        // =====================================================================
        if (errors == 0)
            $display("\nWRITE-BACK MUX TEST PASSED (%0d cases)", tests);
        else
            $display("\nWRITE-BACK MUX TEST FAILED: %0d error(s) in %0d cases",
                     errors, tests);

        $finish;
    end

endmodule
