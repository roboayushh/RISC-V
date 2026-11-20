`timescale 1ns/1ps

// =============================================================================
// tb_rv32i_integration.v — Phase 2 Integration Testbench
//
// Author : Ankit
// Phase  : 2 — Complete Processor Integration and Top-Level Design
//
// Description:
//   Self-checking testbench for the fully integrated single-cycle RV32I
//   processor. Exercises all 10 supported instruction types end-to-end:
//
//     R-type : ADD, SUB, AND, OR, XOR
//     I-type : ADDI
//     Load   : LW
//     Store  : SW
//     Branch : BEQ (taken + not-taken), BNE (taken + not-taken)
//
// Test program: programs/phase2_integration.hex
//
// Verification approach:
//   1. Reset the processor for 2 clock cycles
//   2. Run until halt is detected (PC stuck in infinite loop)
//   3. Check all architectural registers against expected values
//   4. Check data memory contents at stored locations
//   5. Report PASS/FAIL with detailed per-check output
// =============================================================================

module tb_rv32i_integration;

    // =========================================================================
    // Clock and control
    // =========================================================================
    reg         clk;
    reg         reset;
    wire [31:0] pc;
    wire [31:0] instruction;
    wire        halted;
    integer     errors;
    integer     checks;
    integer     cycle_count;

    // =========================================================================
    // DUT: rv32i_top (top-level wrapper)
    // =========================================================================
    rv32i_top #(
        .IMEM_DEPTH     (25),   // 25 instructions in test program
        .IMEM_INIT_FILE ("programs/phase2_integration.hex"),
        .DMEM_DEPTH     (256)
    ) dut (
        .clk       (clk),
        .reset     (reset),
        .pc_out    (pc),
        .instr_out (instruction),
        .halted    (halted)
    );

    // 100 MHz clock (10ns period)
    always #5 clk = ~clk;

    // =========================================================================
    // Helper tasks
    // =========================================================================

    // Check a register value
    task check_reg;
        input [4:0]  idx;
        input [31:0] expected;
        input [255:0] description;
        reg   [31:0] actual;
        begin
            actual = (idx == 5'd0) ? 32'b0 : dut.u_core.u_regfile.registers[idx];
            checks = checks + 1;
            if (actual !== expected) begin
                $display("  FAIL: x%-2d = 0x%08h (expected 0x%08h) — %0s",
                         idx, actual, expected, description);
                errors = errors + 1;
            end else begin
                $display("  PASS: x%-2d = %-5d (0x%08h) — %0s",
                         idx, actual, actual, description);
            end
        end
    endtask

    // Check a data memory word
    task check_mem;
        input integer word_index;
        input [31:0]  expected;
        input [255:0] description;
        reg   [31:0]  actual;
        begin
            actual = dut.u_core.u_dmem.memory[word_index];
            checks = checks + 1;
            if (actual !== expected) begin
                $display("  FAIL: mem[%0d] = 0x%08h (expected 0x%08h) — %0s",
                         word_index, actual, expected, description);
                errors = errors + 1;
            end else begin
                $display("  PASS: mem[%0d] = %-5d (0x%08h) — %0s",
                         word_index, actual, actual, description);
            end
        end
    endtask

    // =========================================================================
    // Main test sequence
    // =========================================================================
    initial begin
        $dumpfile("build/tb_rv32i_integration.vcd");
        $dumpvars(0, tb_rv32i_integration);

        clk = 1'b0;
        reset = 1'b1;
        errors = 0;
        checks = 0;
        cycle_count = 0;

        $display("");
        $display("=============================================================");
        $display(" PHASE 2: RV32I Integration Test");
        $display(" Single-Cycle Processor — All 10 Instructions");
        $display("=============================================================");
        $display("");

        // -----------------------------------------------------------------
        // Reset phase
        // -----------------------------------------------------------------
        $display("[RESET] Holding reset for 2 clock cycles...");
        repeat (2) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;
        $display("[RESET] Released. Processor running.");
        $display("");

        // -----------------------------------------------------------------
        // Execute: run until halted or timeout
        // -----------------------------------------------------------------
        $display("[EXEC]  Running program...");
        while (!halted && cycle_count < 100) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
        end

        if (halted)
            $display("[EXEC]  Processor halted after %0d cycles (PC = 0x%08h).",
                     cycle_count, pc);
        else
            $display("[EXEC]  WARNING: Timeout after %0d cycles! PC = 0x%08h",
                     cycle_count, pc);
        $display("");

        // -----------------------------------------------------------------
        // Verification: R-type instructions
        // -----------------------------------------------------------------
        $display("--- R-type Instructions ---");
        check_reg(5'd3,  32'd30,       "ADD  x3 = x1 + x2 = 10+20");
        check_reg(5'd4,  32'd10,       "SUB  x4 = x2 - x1 = 20-10");
        check_reg(5'd5,  32'd0,        "AND  x5 = x1 & x2 = 0x0A & 0x14");
        check_reg(5'd6,  32'd30,       "OR   x6 = x1 | x2 = 0x0A | 0x14");
        check_reg(5'd7,  32'd30,       "XOR  x7 = x1 ^ x2 = 0x0A ^ 0x14");
        $display("");

        // -----------------------------------------------------------------
        // Verification: I-type (ADDI)
        // -----------------------------------------------------------------
        $display("--- I-type Instructions ---");
        check_reg(5'd1,  32'd10,       "ADDI x1 = x0 + 10");
        check_reg(5'd2,  32'd20,       "ADDI x2 = x0 + 20");
        check_reg(5'd8,  32'd5,        "ADDI x8 = x0 + 5");
        $display("");

        // -----------------------------------------------------------------
        // Verification: Store (SW) + Load (LW)
        // -----------------------------------------------------------------
        $display("--- Memory Instructions (SW + LW) ---");
        check_mem(0,     32'd30,       "SW x3 -> mem[0] = 30");
        check_mem(1,     32'd10,       "SW x4 -> mem[1] = 10");
        check_reg(5'd9,  32'd30,       "LW x9 <- mem[0] = 30");
        check_reg(5'd10, 32'd10,       "LW x10 <- mem[1] = 10");
        $display("");

        // -----------------------------------------------------------------
        // Verification: Branches (BEQ/BNE taken and not-taken)
        // -----------------------------------------------------------------
        $display("--- Branch Instructions (BEQ/BNE) ---");

        // BEQ not taken: x11 should be written (instruction not skipped)
        check_reg(5'd11, 32'd1,        "BEQ not-taken: x11=1 (fall through)");

        // BNE not taken: x12 should be written (instruction not skipped)
        check_reg(5'd12, 32'd2,        "BNE not-taken: x12=2 (fall through)");

        // BEQ taken: x13, x14 should be SKIPPED (remain 0), x15 is target
        check_reg(5'd13, 32'd0,        "BEQ taken: x13=0 (SKIPPED)");
        check_reg(5'd14, 32'd0,        "BEQ taken: x14=0 (SKIPPED)");
        check_reg(5'd15, 32'd42,       "BEQ taken: x15=42 (branch target)");

        // BNE taken: x16, x17 should be SKIPPED (remain 0), x18 is target
        check_reg(5'd16, 32'd0,        "BNE taken: x16=0 (SKIPPED)");
        check_reg(5'd17, 32'd0,        "BNE taken: x17=0 (SKIPPED)");
        check_reg(5'd18, 32'd55,       "BNE taken: x18=55 (branch target)");
        $display("");

        // -----------------------------------------------------------------
        // Summary
        // -----------------------------------------------------------------
        $display("=============================================================");
        if (errors == 0) begin
            $display(" PHASE 2 INTEGRATION TEST PASSED");
            $display(" All %0d checks passed — 10 instruction types verified", checks);
        end else begin
            $display(" PHASE 2 INTEGRATION TEST FAILED");
            $display(" %0d / %0d checks failed", errors, checks);
        end
        $display("=============================================================");
        $display("");

        $finish;
    end

endmodule
