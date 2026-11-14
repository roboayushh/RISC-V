`timescale 1ns/1ps

// =============================================================================
// Self-checking testbench for immediate_generator.v
//
// Tests all three supported immediate formats (I-type, S-type, B-type) with
// boundary conditions and both positive and negative values.  Valid RV32I
// instruction encodings are constructed for every test case so the bit
// extraction logic is exercised exactly as it would be in the real datapath.
//
// Author : Saumya
// =============================================================================

module tb_immediate_generator;

    // -------------------------------------------------------------------------
    // DUT connections
    // -------------------------------------------------------------------------
    reg  [31:0] instruction;
    reg  [1:0]  ImmSrc;
    wire [31:0] imm_ext;

    immediate_generator dut (
        .instruction (instruction),
        .ImmSrc      (ImmSrc),
        .imm_ext     (imm_ext)
    );

    // -------------------------------------------------------------------------
    // Book-keeping
    // -------------------------------------------------------------------------
    integer errors;
    integer tests;

    // -------------------------------------------------------------------------
    // Helper task: check the DUT output and print PASS/FAIL
    // -------------------------------------------------------------------------
    task check;
        input [31:0] instr;
        input [1:0]  src;
        input [31:0] expected;
        input [63:0] label;      // 8-char ASCII label for display
        begin
            instruction = instr;
            ImmSrc      = src;
            #1; // allow combinational logic to settle
            if (imm_ext !== expected) begin
                $display("FAIL [%s]: ImmSrc=%b instr=0x%08h expected=0x%08h got=0x%08h",
                         label, src, instr, expected, imm_ext);
                errors = errors + 1;
            end else begin
                $display("PASS [%s]: ImmSrc=%b imm_ext=0x%08h (%0d)",
                         label, src, imm_ext, $signed(imm_ext));
            end
            tests = tests + 1;
        end
    endtask

    // =========================================================================
    // Instruction encoding helpers
    //
    // For each test case we build a syntactically valid RV32I instruction word
    // so only the specific immediate bits are exercised.
    // Unused opcode/register fields are filled with zeros (they do not affect
    // the immediate extractor).
    // =========================================================================

    // Build an I-type instruction word.
    // imm[11:0] lives in instruction[31:20].
    // Using opcode=0010011 (OP-IMM), funct3=000 (ADDI), rd=x1, rs1=x0.
    function [31:0] build_i_type;
        input [11:0] imm12;
        begin
            // [31:20]=imm, [19:15]=rs1=x0, [14:12]=funct3=000,
            // [11:7]=rd=x1, [6:0]=opcode=0010011
            build_i_type = {imm12, 5'd0, 3'b000, 5'd1, 7'b0010011};
        end
    endfunction

    // Build an S-type instruction word.
    // imm[11:5] in instruction[31:25], imm[4:0] in instruction[11:7].
    // Using opcode=0100011 (STORE), funct3=010 (SW), rs1=x0, rs2=x3.
    function [31:0] build_s_type;
        input [11:0] imm12;
        begin
            // [31:25]=imm[11:5], [24:20]=rs2=x3, [19:15]=rs1=x0,
            // [14:12]=funct3=010, [11:7]=imm[4:0], [6:0]=opcode=0100011
            build_s_type = {imm12[11:5], 5'd3, 5'd0, 3'b010,
                            imm12[4:0], 7'b0100011};
        end
    endfunction

    // Build a B-type instruction word.
    // imm[12]   -> instruction[31]
    // imm[10:5] -> instruction[30:25]
    // imm[4:1]  -> instruction[11:8]
    // imm[11]   -> instruction[7]
    // (imm[0] is always 0 and not stored in the instruction)
    // Using opcode=1100011 (BRANCH), funct3=000 (BEQ), rs1=x1, rs2=x2.
    function [31:0] build_b_type;
        input [12:0] imm13; // imm13[0] must be 0 (even), imm13[12] is sign
        begin
            // [31]    = imm[12]
            // [30:25] = imm[10:5]
            // [24:20] = rs2 = x2
            // [19:15] = rs1 = x1
            // [14:12] = funct3 = 000
            // [11:8]  = imm[4:1]
            // [7]     = imm[11]
            // [6:0]   = opcode = 1100011
            build_b_type = {imm13[12], imm13[10:5], 5'd2, 5'd1, 3'b000,
                            imm13[4:1], imm13[11], 7'b1100011};
        end
    endfunction

    // =========================================================================
    // Simulation body
    // =========================================================================
    initial begin
        $dumpfile("build/tb_immediate_generator.vcd");
        $dumpvars(0, tb_immediate_generator);

        errors = 0;
        tests  = 0;
        instruction = 32'b0;
        ImmSrc      = 2'b00;

        // =====================================================================
        // I-TYPE tests  (ImmSrc = 2'b00)
        // =====================================================================

        // imm = 0  -> 32'h00000000
        check(build_i_type(12'd0),    2'b00, 32'h00000000, "I imm=0 ");

        // imm = 1  -> 32'h00000001
        check(build_i_type(12'd1),    2'b00, 32'h00000001, "I imm=1 ");

        // imm = -1 (12-bit two's complement: 12'hFFF) -> sign-extend to 32'hFFFFFFFF
        check(build_i_type(12'hFFF),  2'b00, 32'hFFFFFFFF, "I imm=-1");

        // Maximum positive 12-bit I-type immediate: 2047 = 12'h7FF -> 32'h000007FF
        check(build_i_type(12'h7FF),  2'b00, 32'h000007FF, "I max+  ");

        // Minimum negative 12-bit I-type immediate: -2048 = 12'h800 -> 32'hFFFFF800
        check(build_i_type(12'h800),  2'b00, 32'hFFFFF800, "I min-  ");

        // =====================================================================
        // S-TYPE tests  (ImmSrc = 2'b01)
        // =====================================================================

        // imm = 0
        check(build_s_type(12'd0),    2'b01, 32'h00000000, "S imm=0 ");

        // imm = 1
        check(build_s_type(12'd1),    2'b01, 32'h00000001, "S imm=1 ");

        // imm = -1 (12'hFFF)
        check(build_s_type(12'hFFF),  2'b01, 32'hFFFFFFFF, "S imm=-1");

        // Maximum positive: 2047 = 12'h7FF
        check(build_s_type(12'h7FF),  2'b01, 32'h000007FF, "S max+  ");

        // Minimum negative: -2048 = 12'h800
        check(build_s_type(12'h800),  2'b01, 32'hFFFFF800, "S min-  ");

        // =====================================================================
        // B-TYPE tests  (ImmSrc = 2'b10)
        //
        // The 13-bit B-type immediate (imm13) is a signed even offset.
        // imm13[0] is always 0 (branch offsets address 2-byte boundaries).
        // Range: -4096 to +4094.
        // =====================================================================

        // imm = 0  -> 32'h00000000
        check(build_b_type(13'd0),    2'b10, 32'h00000000, "B imm=0 ");

        // imm = 2 (smallest positive even offset)
        // 13-bit: 13'b0_0000_0000_0010
        check(build_b_type(13'd2),    2'b10, 32'h00000002, "B imm=2 ");

        // imm = -2 (13-bit two's complement: 13'b1_1111_1111_1110 = 13'h1FFE)
        // Expected sign-extension: 32'hFFFFFFFE
        check(build_b_type(13'h1FFE), 2'b10, 32'hFFFFFFFE, "B imm=-2");

        // Large positive: 4094 = 0x0FFE, 13-bit = 13'h0FFE
        // imm12=12, imm11=0, imm[10:5]=111111, imm[4:1]=1111
        check(build_b_type(13'h0FFE), 2'b10, 32'h00000FFE, "B +4094 ");

        // Most negative: -4096 = 13'b1_0000_0000_0000 = 13'h1000
        // Expected: 32'hFFFFF000
        check(build_b_type(13'h1000), 2'b10, 32'hFFFFF000, "B -4096 ");

        // =====================================================================
        // B-TYPE structural checks
        // =====================================================================

        // Verify bit[0] of B-type imm_ext is ALWAYS 0 regardless of encoding.
        // Use imm = +4094 (all lower bits set to 1 except bit 0).
        begin : b_bit0_check
            reg [31:0] instr_b;
            instr_b = build_b_type(13'h0FFE);
            instruction = instr_b;
            ImmSrc      = 2'b10;
            #1;
            if (imm_ext[0] !== 1'b0) begin
                $display("FAIL [B bit0 ]: B-type imm_ext[0] should be 0, got %b (imm_ext=0x%08h)",
                         imm_ext[0], imm_ext);
                errors = errors + 1;
            end else begin
                $display("PASS [B bit0 ]: B-type imm_ext[0]=0 (branch targets are even)");
            end
            tests = tests + 1;
        end

        // =====================================================================
        // Default / unsupported ImmSrc -> must output 32'b0
        // =====================================================================
        check(32'hFFFFFFFF, 2'b11, 32'h00000000, "default ");

        // =====================================================================
        // Summary
        // =====================================================================
        if (errors == 0)
            $display("\nIMMEDIATE GENERATOR TEST PASSED (%0d cases)", tests);
        else
            $display("\nIMMEDIATE GENERATOR TEST FAILED: %0d error(s) in %0d cases",
                     errors, tests);

        $finish;
    end

endmodule
