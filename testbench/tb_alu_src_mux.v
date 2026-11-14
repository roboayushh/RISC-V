`timescale 1ns/1ps

// =============================================================================
// Self-checking testbench for alu_src_mux.v
//
// Tests both selector values with distinct operand patterns so that an
// incorrect selection is unambiguously detectable.
//
// Author : Saumya
// =============================================================================

module tb_alu_src_mux;

    // -------------------------------------------------------------------------
    // DUT connections
    // -------------------------------------------------------------------------
    reg  [31:0] reg_data2;
    reg  [31:0] imm_ext;
    reg         ALUSrc;
    wire [31:0] alu_operand_b;

    alu_src_mux dut (
        .reg_data2     (reg_data2),
        .imm_ext       (imm_ext),
        .ALUSrc        (ALUSrc),
        .alu_operand_b (alu_operand_b)
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
        input [31:0] rd2;      // reg_data2 value
        input [31:0] imm;      // imm_ext value
        input        sel;      // ALUSrc selector
        input [31:0] expected; // expected alu_operand_b
        begin
            reg_data2 = rd2;
            imm_ext   = imm;
            ALUSrc    = sel;
            #1;
            if (alu_operand_b !== expected) begin
                $display("FAIL: ALUSrc=%b reg_data2=0x%08h imm_ext=0x%08h expected=0x%08h got=0x%08h",
                         sel, rd2, imm, expected, alu_operand_b);
                errors = errors + 1;
            end else begin
                $display("PASS: ALUSrc=%b -> alu_operand_b=0x%08h (correct)",
                         sel, alu_operand_b);
            end
            tests = tests + 1;
        end
    endtask

    // =========================================================================
    // Simulation body
    // =========================================================================
    initial begin
        $dumpfile("build/tb_alu_src_mux.vcd");
        $dumpvars(0, tb_alu_src_mux);

        errors = 0;
        tests  = 0;

        // =====================================================================
        // ALUSrc = 0: select reg_data2
        // =====================================================================

        // Basic case: distinct values so we can tell which was chosen.
        check(32'hAAAAAAAA, 32'h55555555, 1'b0, 32'hAAAAAAAA);

        // reg_data2 = 0 (R-type with zero operand)
        check(32'h00000000, 32'hDEADBEEF, 1'b0, 32'h00000000);

        // reg_data2 = max positive
        check(32'h7FFFFFFF, 32'h00000001, 1'b0, 32'h7FFFFFFF);

        // reg_data2 = all ones
        check(32'hFFFFFFFF, 32'h00000000, 1'b0, 32'hFFFFFFFF);

        // =====================================================================
        // ALUSrc = 1: select imm_ext
        // =====================================================================

        // Basic case: distinct values
        check(32'hAAAAAAAA, 32'h55555555, 1'b1, 32'h55555555);

        // imm_ext = 0 (zero immediate)
        check(32'hDEADBEEF, 32'h00000000, 1'b1, 32'h00000000);

        // imm_ext = negative (-1 sign-extended)
        check(32'h00000005, 32'hFFFFFFFF, 1'b1, 32'hFFFFFFFF);

        // imm_ext = typical ADDI immediate (+12)
        check(32'h00000007, 32'h0000000C, 1'b1, 32'h0000000C);

        // =====================================================================
        // Cross-check: switching ALUSrc toggles between inputs correctly
        // =====================================================================
        reg_data2 = 32'h12345678;
        imm_ext   = 32'h9ABCDEF0;
        ALUSrc = 1'b0; #1;
        if (alu_operand_b !== 32'h12345678) begin
            $display("FAIL [switch]: ALUSrc=0 expected 0x12345678 got 0x%08h", alu_operand_b);
            errors = errors + 1;
        end else
            $display("PASS [switch]: ALUSrc=0 -> 0x%08h", alu_operand_b);
        tests = tests + 1;

        ALUSrc = 1'b1; #1;
        if (alu_operand_b !== 32'h9ABCDEF0) begin
            $display("FAIL [switch]: ALUSrc=1 expected 0x9ABCDEF0 got 0x%08h", alu_operand_b);
            errors = errors + 1;
        end else
            $display("PASS [switch]: ALUSrc=1 -> 0x%08h", alu_operand_b);
        tests = tests + 1;

        // =====================================================================
        // Summary
        // =====================================================================
        if (errors == 0)
            $display("\nALU SRC MUX TEST PASSED (%0d cases)", tests);
        else
            $display("\nALU SRC MUX TEST FAILED: %0d error(s) in %0d cases",
                     errors, tests);

        $finish;
    end

endmodule
