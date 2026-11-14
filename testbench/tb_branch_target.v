`timescale 1ns/1ps

// =============================================================================
// Self-checking testbench for branch_target.v
//
// Tests PC + immediate addition for a range of PC and immediate values,
// including positive offsets, negative offsets, zero, and boundary conditions.
//
// Author : Saumya
// =============================================================================

module tb_branch_target;

    // -------------------------------------------------------------------------
    // DUT connections
    // -------------------------------------------------------------------------
    reg  [31:0] pc;
    reg  [31:0] imm_ext;
    wire [31:0] branch_target_addr;

    branch_target dut (
        .pc                 (pc),
        .imm_ext            (imm_ext),
        .branch_target_addr (branch_target_addr)
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
        input [31:0] pc_val;
        input [31:0] imm_val;
        input [31:0] expected;
        begin
            pc      = pc_val;
            imm_ext = imm_val;
            #1;
            if (branch_target_addr !== expected) begin
                $display("FAIL: pc=0x%08h imm=0x%08h expected=0x%08h got=0x%08h",
                         pc_val, imm_val, expected, branch_target_addr);
                errors = errors + 1;
            end else begin
                $display("PASS: 0x%08h + 0x%08h = 0x%08h (%0d + %0d = %0d)",
                         pc_val, imm_val, branch_target_addr,
                         pc_val, $signed(imm_val), $signed(branch_target_addr));
            end
            tests = tests + 1;
        end
    endtask

    // =========================================================================
    // Simulation body
    // =========================================================================
    initial begin
        $dumpfile("build/tb_branch_target.vcd");
        $dumpvars(0, tb_branch_target);

        errors = 0;
        tests  = 0;

        // =====================================================================
        // Zero immediate: BranchTarget = PC + 0 = PC
        // =====================================================================
        check(32'h00000000, 32'h00000000, 32'h00000000); // PC=0, imm=0
        check(32'h00000008, 32'h00000000, 32'h00000008); // PC=8, imm=0
        check(32'h00000100, 32'h00000000, 32'h00000100); // PC=256, imm=0

        // =====================================================================
        // Positive immediate (forward branch)
        // =====================================================================
        // BEQ offset +2 (smallest positive B-type step)
        check(32'h00000000, 32'h00000002, 32'h00000002);

        // Typical small forward branch: PC=0x08, offset=+8 -> target=0x10
        check(32'h00000008, 32'h00000008, 32'h00000010);

        // PC=0x20, offset=+0x40 -> 0x60
        check(32'h00000020, 32'h00000040, 32'h00000060);

        // Large positive offset: PC=0x100, offset=+4094 (max B-type +)
        check(32'h00000100, 32'h00000FFE, 32'h000010FE);

        // =====================================================================
        // Negative immediate (backward branch)
        // =====================================================================
        // imm = -2 (sign-extended: 32'hFFFFFFFE)
        check(32'h00000008, 32'hFFFFFFFE, 32'h00000006);

        // Loop back: PC=0x20, offset=-32 (imm=-32=32'hFFFFFFE0) -> target=0x00
        check(32'h00000020, 32'hFFFFFFE0, 32'h00000000);

        // PC=0x1000, offset=-4096 (min B-type: imm=32'hFFFFF000) -> 0x0000
        check(32'h00001000, 32'hFFFFF000, 32'h00000000);

        // PC=0x20, offset=-2 -> 0x1E
        check(32'h00000020, 32'hFFFFFFFE, 32'h0000001E);

        // =====================================================================
        // Different PC base values, same offset
        // =====================================================================
        check(32'h00000004, 32'h00000010, 32'h00000014);
        check(32'h00000008, 32'h00000010, 32'h00000018);
        check(32'h0000000C, 32'h00000010, 32'h0000001C);
        check(32'h00000010, 32'h00000010, 32'h00000020);

        // =====================================================================
        // 32-bit wrap-around (modular arithmetic)
        // PC near top of address space + positive offset wraps to low address
        // =====================================================================
        // 0xFFFFFFFC + 4 = 0x00000000 (mod 2^32)
        check(32'hFFFFFFFC, 32'h00000004, 32'h00000000);

        // =====================================================================
        // Real instruction scenario:
        // "BEQ x1, x2, loop" where loop is 12 bytes back
        // PC = 0x0C, B-type imm = -12 = 32'hFFFFFFF4
        // Expected target: 0x0C + 0xFFFFFFF4 = 0x00000000
        // =====================================================================
        check(32'h0000000C, 32'hFFFFFFF4, 32'h00000000);

        // "BNE x1, x2, skip" where skip is 8 bytes ahead
        // PC = 0x04, B-type imm = +8 = 32'h00000008
        // Expected target: 0x04 + 0x08 = 0x0C
        check(32'h00000004, 32'h00000008, 32'h0000000C);

        // =====================================================================
        // Summary
        // =====================================================================
        if (errors == 0)
            $display("\nBRANCH TARGET TEST PASSED (%0d cases)", tests);
        else
            $display("\nBRANCH TARGET TEST FAILED: %0d error(s) in %0d cases",
                     errors, tests);

        $finish;
    end

endmodule
