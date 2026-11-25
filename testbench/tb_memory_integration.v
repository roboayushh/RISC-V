`timescale 1ns/1ps

// =============================================================================
// tb_memory_integration.v — Phase 2 Data Memory / LW / SW Verification
//
// Author : Rashmi
// Phase  : 2 — Data Memory Integration, LW/SW Execution and Memory Verification
//
// Purpose:
//   A dedicated, self-checking testbench for the LOAD/STORE datapath of the
//   integrated single-cycle RV32I processor. It does NOT build a new/parallel
//   datapath: it instantiates the real, already-integrated top-level
//   (rv32i_top -> rv32i_core -> data_memory u_dmem, register_file u_regfile)
//   exactly as Ankit wired it, and verifies memory behaviour end-to-end.
//
//   Five independent program images are run in five DUT instances so that a
//   single `vvp` run covers all twelve required memory test cases:
//
//     dut_basic  (programs/mem_basic.hex)       basic SW then LW, ADD of result
//     dut_multi  (programs/mem_multi.hex)       multiple locations + no-clobber + SW!=reg
//     dut_consec (programs/mem_consecutive.hex) zero, 0xFFFFFFFF, +offset, -offset
//     dut_mixed  (programs/mem_mixed.hex)       arithmetic still works around memory
//     dut_branch (programs/mem_branch.hex)      memory interleaved with taken branches
//
// Addressing convention (verified from rtl/data_memory.v):
//   The memory is BYTE-ADDRESSED. The word index is address[.. :2] (i.e.
//   byte_address >> 2). So base x1 = 64 with offset 0 -> byte addr 64 -> word 16.
//   Reads are asynchronous and gated by MemRead; writes are synchronous (posedge
//   clk) and gated by MemWrite; both require 4-byte alignment and in-range index.
//
// Every check prints TEST INPUT (implicit in the label), EXPECTED and ACTUAL
// values and an explicit PASS/FAIL. A final summary reports total pass/fail.
// =============================================================================

module tb_memory_integration;

    // Shared clock / reset for all DUTs.
    reg clk;
    reg reset;

    integer errors;
    integer checks;
    integer cyc;

    // Observed (unused) top-level outputs — kept to match the real port list.
    wire [31:0] pc_b, in_b, pc_m, in_m, pc_c, in_c, pc_x, in_x, pc_r, in_r;
    wire        h_b, h_m, h_c, h_x, h_r;

    // IMEM_DEPTH is set to each program's exact word count so $readmemh fills
    // the whole array (no benign "not enough words" note), matching repo style.

    rv32i_top #(.IMEM_DEPTH(6),  .IMEM_INIT_FILE("programs/mem_basic.hex"),       .DMEM_DEPTH(256))
        dut_basic  (.clk(clk), .reset(reset), .pc_out(pc_b), .instr_out(in_b), .halted(h_b));

    rv32i_top #(.IMEM_DEPTH(8),  .IMEM_INIT_FILE("programs/mem_multi.hex"),       .DMEM_DEPTH(256))
        dut_multi  (.clk(clk), .reset(reset), .pc_out(pc_m), .instr_out(in_m), .halted(h_m));

    rv32i_top #(.IMEM_DEPTH(10), .IMEM_INIT_FILE("programs/mem_consecutive.hex"), .DMEM_DEPTH(256))
        dut_consec (.clk(clk), .reset(reset), .pc_out(pc_c), .instr_out(in_c), .halted(h_c));

    rv32i_top #(.IMEM_DEPTH(14), .IMEM_INIT_FILE("programs/mem_mixed.hex"),       .DMEM_DEPTH(256))
        dut_mixed  (.clk(clk), .reset(reset), .pc_out(pc_x), .instr_out(in_x), .halted(h_x));

    rv32i_top #(.IMEM_DEPTH(14), .IMEM_INIT_FILE("programs/mem_branch.hex"),      .DMEM_DEPTH(256))
        dut_branch (.clk(clk), .reset(reset), .pc_out(pc_r), .instr_out(in_r), .halted(h_r));

    // 100 MHz clock.
    always #5 clk = ~clk;

    // Generic self-check: caller dereferences the DUT value and passes it in.
    task check;
        input [511:0] label;
        input [31:0]  actual;
        input [31:0]  expected;
        begin
            checks = checks + 1;
            if (actual === expected) begin
                $display("  PASS | %-0s | expected=0x%08h actual=0x%08h", label, expected, actual);
            end else begin
                $display("  FAIL | %-0s | expected=0x%08h actual=0x%08h", label, expected, actual);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("build/tb_memory_integration.vcd");
        $dumpvars(0, tb_memory_integration);

        clk    = 1'b0;
        reset  = 1'b1;
        errors = 0;
        checks = 0;
        cyc    = 0;

        $display("");
        $display("=============================================================");
        $display(" PHASE 2: DATA MEMORY / LW / SW INTEGRATION VERIFICATION");
        $display(" Author: Rashmi   (byte-addressed, word index = addr>>2)");
        $display("=============================================================");

        // Hold reset for 2 cycles, release on a negedge (clean setup).
        repeat (2) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        // Every program ends in BEQ x0,x0,0 (self-loop). Single-cycle, longest
        // program is 14 instructions, so 60 cycles is comfortably enough for all
        // five DUTs to finish and settle.
        while (cyc < 60) begin
            @(posedge clk);
            cyc = cyc + 1;
        end

        // ----------------------------------------------------------------- basic
        $display("");
        $display("--- [mem_basic] basic SW then LW (Case 1,2 + write-back + SW!=reg) ---");
        check("basic: x1 = 64 (base addr in reg)",          dut_basic.u_core.u_regfile.registers[1],  32'd64);
        check("basic: x2 = 25 (value to store)",            dut_basic.u_core.u_regfile.registers[2],  32'd25);
        check("basic: mem[word16] = 25 (SW stored value)",  dut_basic.u_core.u_dmem.memory[16],        32'd25);
        check("basic: x3 = 25 (LW loaded into rd=x3)",      dut_basic.u_core.u_regfile.registers[3],  32'd25);
        check("basic: x4 = 50 (ADD x2+x3 after load)",      dut_basic.u_core.u_regfile.registers[4],  32'd50);

        // ----------------------------------------------------------------- multi
        $display("");
        $display("--- [mem_multi] multiple locations (Case 5,6,7,8,9) ---");
        check("multi: mem[word16] = 100 (SW loc A)",        dut_multi.u_core.u_dmem.memory[16],        32'd100);
        check("multi: mem[word17] = 200 (SW loc B, +4)",    dut_multi.u_core.u_dmem.memory[17],        32'd200);
        check("multi: x3 = 100 (LW A: B's store didn't clobber A)", dut_multi.u_core.u_regfile.registers[3], 32'd100);
        check("multi: x6 = 200 (LW B into rd=x6)",          dut_multi.u_core.u_regfile.registers[6],  32'd200);
        // Case 8: `SW x5,4(x1)` has imm[4:0]=00100 in the rd-field position (=x4).
        // RegWrite=0 for SW, so x4 must NOT be written.
        check("multi: x4 = 0 (SW must NOT write a register)", dut_multi.u_core.u_regfile.registers[4], 32'd0);

        // ------------------------------------------------------------- consecutive
        $display("");
        $display("--- [mem_consecutive] zero / 32-bit / +offset / -offset (Case 3,4,10,11) ---");
        check("consec: mem[word16] = 0 (store zero)",       dut_consec.u_core.u_dmem.memory[16],       32'd0);
        check("consec: x3 = 0 (load zero back)",            dut_consec.u_core.u_regfile.registers[3], 32'd0);
        check("consec: mem[word18] = 0xFFFFFFFF (+8)",      dut_consec.u_core.u_dmem.memory[18],       32'hFFFFFFFF);
        check("consec: x8 = 0xFFFFFFFF (LW +8)",            dut_consec.u_core.u_regfile.registers[8], 32'hFFFFFFFF);
        check("consec: mem[word15] = 0xFFFFFFFF (SW -4)",   dut_consec.u_core.u_dmem.memory[15],       32'hFFFFFFFF);
        check("consec: x9 = 0xFFFFFFFF (LW -4, neg offset)",dut_consec.u_core.u_regfile.registers[9], 32'hFFFFFFFF);

        // ----------------------------------------------------------------- mixed
        $display("");
        $display("--- [mem_mixed] arithmetic intact around memory (Case 12) ---");
        check("mixed: x4 = 12  (ADD before SW)",            dut_mixed.u_core.u_regfile.registers[4],  32'd12);
        check("mixed: x5 = 2   (SUB)",                      dut_mixed.u_core.u_regfile.registers[5],  32'd2);
        check("mixed: mem[word16] = 12 (SW)",               dut_mixed.u_core.u_dmem.memory[16],        32'd12);
        check("mixed: x6 = 12  (LW)",                       dut_mixed.u_core.u_regfile.registers[6],  32'd12);
        check("mixed: x7 = 14  (ADD using loaded value)",   dut_mixed.u_core.u_regfile.registers[7],  32'd14);
        check("mixed: mem[word17] = 14 (SW)",               dut_mixed.u_core.u_dmem.memory[17],        32'd14);
        check("mixed: x8 = 14  (LW)",                       dut_mixed.u_core.u_regfile.registers[8],  32'd14);
        check("mixed: x9 = 2   (XOR after memory)",         dut_mixed.u_core.u_regfile.registers[9],  32'd2);
        check("mixed: x10 = 5  (AND after memory)",         dut_mixed.u_core.u_regfile.registers[10], 32'd5);
        check("mixed: x11 = 7  (OR after memory)",          dut_mixed.u_core.u_regfile.registers[11], 32'd7);

        // ----------------------------------------------------------------- branch
        $display("");
        $display("--- [mem_branch] memory interleaved with taken branches ---");
        check("branch: mem[word16] = 11 (SW)",              dut_branch.u_core.u_dmem.memory[16],       32'd11);
        check("branch: x4 = 11 (LW)",                       dut_branch.u_core.u_regfile.registers[4], 32'd11);
        check("branch: x5 = 0  (BEQ taken -> ADDI skipped)",dut_branch.u_core.u_regfile.registers[5], 32'd0);
        check("branch: x6 = 7  (branch target reached)",    dut_branch.u_core.u_regfile.registers[6], 32'd7);
        check("branch: mem[word17] = 7 (SW after branch)",  dut_branch.u_core.u_dmem.memory[17],       32'd7);
        check("branch: x7 = 7  (LW after branch)",          dut_branch.u_core.u_regfile.registers[7], 32'd7);
        check("branch: x8 = 0  (BNE taken -> ADDI skipped)",dut_branch.u_core.u_regfile.registers[8], 32'd0);
        check("branch: x9 = 3  (post-branch ADDI)",         dut_branch.u_core.u_regfile.registers[9], 32'd3);

        // --------------------------------------------------------------- summary
        $display("");
        $display("=============================================================");
        if (errors == 0)
            $display(" MEMORY INTEGRATION TEST PASSED  (%0d/%0d checks)", checks, checks);
        else
            $display(" MEMORY INTEGRATION TEST FAILED  (%0d of %0d checks failed)", errors, checks);
        $display("=============================================================");
        $display("");

        if (errors != 0) $fatal(1, "Integration checks failed");
        $finish;
    end

endmodule
