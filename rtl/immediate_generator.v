`timescale 1ns/1ps

// =============================================================================
// Immediate Generator for the single-cycle RV32I processor.
//
// Extracts and sign-extends the immediate field from a 32-bit RV32I instruction
// word.  Only the three immediate formats required by the current project are
// supported:
//
//   ImmSrc  Format   Instructions
//   2'b00   I-type   ADDI, LW
//   2'b01   S-type   SW
//   2'b10   B-type   BEQ, BNE
//
// For unsupported ImmSrc values the output is forced to 32'b0 (safe default).
//
// All logic is purely combinational — no clock port is needed.
//
// Author : Saumya
// Module : immediate_generator
// =============================================================================

module immediate_generator (
    // The full 32-bit instruction word coming from Instruction Memory.
    input  wire [31:0] instruction,

    // ImmSrc: selects which immediate format to extract.
    //   2'b00 -> I-type
    //   2'b01 -> S-type
    //   2'b10 -> B-type
    input  wire [1:0]  ImmSrc,

    // Sign-extended 32-bit immediate value.
    output reg  [31:0] imm_ext
);

    // -------------------------------------------------------------------------
    // Bit-field aliases (improves readability and matches the RISC-V spec).
    // These are purely combinational aliases — no hardware cost.
    // -------------------------------------------------------------------------

    // Sign bit (bit 31) is the MSB of every RV32I immediate format.
    wire sign = instruction[31];

    // I-type:  imm[11:0]  = instruction[31:20]
    // S-type:  imm[11:5]  = instruction[31:25]   imm[4:0] = instruction[11:7]
    // B-type:  imm[12]    = instruction[31]
    //          imm[11]    = instruction[7]
    //          imm[10:5]  = instruction[30:25]
    //          imm[4:1]   = instruction[11:8]
    //          imm[0]     = 1'b0  (B-type offsets are always even)

    always @(*) begin
        case (ImmSrc)

            // -----------------------------------------------------------------
            // I-type immediate (12 bits, sign-extended to 32 bits).
            // Used by: ADDI, LW (address offset), JALR (not in scope but same).
            //
            // Instruction encoding  [31:20] holds imm[11:0].
            // Sign extension replicates bit 31 into the upper 20 bits.
            // -----------------------------------------------------------------
            2'b00: imm_ext = {{20{sign}}, instruction[31:20]};

            // -----------------------------------------------------------------
            // S-type immediate (12 bits, sign-extended to 32 bits).
            // Used by: SW
            //
            // The 12-bit immediate is split across two non-adjacent fields:
            //   bits [31:25] carry imm[11:5]
            //   bits [11:7]  carry imm[4:0]
            // -----------------------------------------------------------------
            2'b01: imm_ext = {{20{sign}}, instruction[31:25], instruction[11:7]};

            // -----------------------------------------------------------------
            // B-type immediate (13 bits, sign-extended to 32 bits).
            // Used by: BEQ, BNE
            //
            // The 13-bit signed offset is assembled in a scrambled order in the
            // instruction encoding (RISC-V keeps rs1/rs2 in fixed bit positions):
            //   bit 31      -> imm[12]
            //   bit 7       -> imm[11]
            //   bits [30:25]-> imm[10:5]
            //   bits [11:8] -> imm[4:1]
            //   (imm[0] is always 0 because branches target even byte addresses)
            //
            // After assembly:
            //   imm_ext[31:13] = {19{sign}}   (sign extension)
            //   imm_ext[12]    = instruction[31]
            //   imm_ext[11]    = instruction[7]
            //   imm_ext[10:5]  = instruction[30:25]
            //   imm_ext[4:1]   = instruction[11:8]
            //   imm_ext[0]     = 1'b0
            // -----------------------------------------------------------------
            2'b10: imm_ext = {{19{sign}},
                               instruction[31],
                               instruction[7],
                               instruction[30:25],
                               instruction[11:8],
                               1'b0};

            // -----------------------------------------------------------------
            // Default: unsupported ImmSrc code -> drive zero.
            // This prevents undefined/X propagation into the datapath.
            // -----------------------------------------------------------------
            default: imm_ext = 32'b0;

        endcase
    end

endmodule
