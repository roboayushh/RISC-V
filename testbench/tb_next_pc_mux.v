`timescale 1ns/1ps

// =============================================================================
// Self-checking testbench for next_pc_mux.v
//
// Tests both selector values: sequential PC+4 and branch-target selection.
// Uses distinct address patterns so an incorrect selection is detectable.
//
// Author : Saumya
// =============================================================================

module tb_next_pc_mux;

    // -------------------------------------------------------------------------
    // DUT connections
    // -------------------------------------------------------------------------
    reg  [31:0] pc_plus4;
    reg  [31:0] branch_target;
    reg         PCSrc;
    wire [31:0] next_pc;

    next_pc_mux dut (
        .pc_plus4      (pc_plus4),
        .branch_target (branch_target),
        .PCSrc         (PCSrc),
        .next_pc       (next_pc)
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
        input [31:0] seq;      // pc_plus4 value
        input [31:0] brt;      // branch_target value
        input        sel;      // PCSrc
        input [31:0] expected;
        begin
            pc_plus4      = seq;
            branch_target = brt;
            PCSrc         = sel;
            #1;
            if (next_pc !== expected) begin
                $display("FAIL: PCSrc=%b pc_plus4=0x%08h branch_target=0x%08h expected=0x%08h got=0x%08h",
                         sel, seq, brt, expected, next_pc);
                errors = errors + 1;
            end else begin
                $display("PASS: PCSrc=%b -> next_pc=0x%08h (correct)", sel, next_pc);
            end
            tests = tests + 1;
        end
    endtask

    // =========================================================================
    // Simulation body
    // =========================================================================
    initial begin
        $dumpfile("build/tb_next_pc_mux.vcd");
        $dumpvars(0, tb_next_pc_mux);

        errors = 0;
        tests  = 0;

        // =====================================================================
        // PCSrc = 0: select pc_plus4  (sequential execution, branch not taken)
        // =====================================================================

        // Typical first sequential step: PC was 0, next is 4
        check(32'h00000004, 32'h00000100, 1'b0, 32'h00000004);

        // After several instructions
        check(32'h00000008, 32'h00000200, 1'b0, 32'h00000008);
        check(32'h00000020, 32'h00000040, 1'b0, 32'h00000020);

        // PC+4 = zero edge case (should not happen in practice but tests MUX)
        check(32'h00000000, 32'hDEADBEEF, 1'b0, 32'h00000000);

        // PC+4 = max address
        check(32'hFFFFFFFC, 32'h00000000, 1'b0, 32'hFFFFFFFC);

        // =====================================================================
        // PCSrc = 1: select branch_target  (branch taken)
        // =====================================================================

        // Forward branch (positive offset)
        check(32'h00000008, 32'h00000020, 1'b1, 32'h00000020);

        // Backward branch (negative offset, branch loops back)
        check(32'h0000001C, 32'h00000004, 1'b1, 32'h00000004);

        // Branch to self (infinite loop in hardware)
        check(32'h00000010, 32'h00000010, 1'b1, 32'h00000010);

        // Branch target = zero (reset target)
        check(32'h00000080, 32'h00000000, 1'b1, 32'h00000000);

        // =====================================================================
        // Switch check: same inputs, PCSrc toggling gives different outputs
        // =====================================================================
        pc_plus4      = 32'hAAAAAAAA;
        branch_target = 32'h55555554; // even address (branch targets are even)
        PCSrc = 1'b0; #1;
        if (next_pc !== 32'hAAAAAAAA) begin
            $display("FAIL [switch]: PCSrc=0 expected 0xAAAAAAAA got 0x%08h", next_pc);
            errors = errors + 1;
        end else
            $display("PASS [switch]: PCSrc=0 -> 0x%08h", next_pc);
        tests = tests + 1;

        PCSrc = 1'b1; #1;
        if (next_pc !== 32'h55555554) begin
            $display("FAIL [switch]: PCSrc=1 expected 0x55555554 got 0x%08h", next_pc);
            errors = errors + 1;
        end else
            $display("PASS [switch]: PCSrc=1 -> 0x%08h", next_pc);
        tests = tests + 1;

        // =====================================================================
        // Summary
        // =====================================================================
        if (errors == 0)
            $display("\nNEXT PC MUX TEST PASSED (%0d cases)", tests);
        else
            $display("\nNEXT PC MUX TEST FAILED: %0d error(s) in %0d cases",
                     errors, tests);

        $finish;
    end

endmodule
