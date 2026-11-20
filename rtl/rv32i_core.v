`timescale 1ns/1ps

// =============================================================================
// rv32i_core.v — Complete Single-Cycle RV32I Processor Core (Phase 2)
//
// Author : Ankit
// Phase  : 2 — Complete Processor Integration and Top-Level Design
//
// Description:
//   Combines all Phase 1 modules into a fully functional single-cycle RV32I
//   processor core supporting 10 instructions:
//     R-type : ADD, SUB, AND, OR, XOR
//     I-type : ADDI
//     Load   : LW
//     Store  : SW
//     Branch : BEQ, BNE
//
// Integration tasks completed:
//   1. Integrated Program Counter and Instruction Memory  (Fetch stage)
//   2. Connected Register File, Immediate Generator, ALU  (Decode/Execute)
//   3. Integrated Main Control Unit and ALU Control Unit   (Control path)
//   4. Connected Data Memory and Write-Back logic          (Memory/WB stage)
//   5. Integrated Branch Target and Next-PC selection      (Branch logic)
//   6. Verified correct communication between all modules
//   7. Debugged integration errors
//   8. Finalized single-cycle datapath
//
// Module hierarchy (all instantiated here):
//   program_counter      — 32-bit PC with synchronous reset
//   instruction_memory   — ROM, initialized from hex file
//   control_unit         — Main decoder (opcode → control signals)
//   register_file        — 32×32-bit, 2R/1W, x0 hardwired to 0
//   immediate_generator  — I/S/B-type immediate extraction & sign extension
//   alu_src_mux          — Selects ALU operand B (register vs immediate)
//   alu_control          — Maps ALUOp + funct fields → ALU operation
//   alu                  — 32-bit ALU (ADD/SUB/AND/OR/XOR)
//   data_memory          — 256×32-bit RAM, async read, sync write
//   writeback_mux        — Selects register write data (ALU vs memory)
//   branch_target        — Computes PC + B-type immediate
//   next_pc_mux          — Selects next PC (PC+4 vs branch target)
// =============================================================================

module rv32i_core #(
    parameter IMEM_DEPTH     = 64,       // Number of instruction words
    parameter IMEM_INIT_FILE = "programs/full_demo.hex",  // Program image
    parameter DMEM_DEPTH     = 256       // Number of data memory words
) (
    input  wire        clk,
    input  wire        reset,
    output wire [31:0] pc,               // Current program counter
    output wire [31:0] instruction       // Current instruction word
);

    // =========================================================================
    // Internal wires
    // =========================================================================

    // --- Fetch stage ---
    wire [31:0] pc_current;              // PC register output
    wire [31:0] pc_plus4;                // Sequential next address
    wire [31:0] branch_addr;             // Branch target address
    wire [31:0] next_pc_wire;            // Selected next PC

    // --- Decode stage ---
    wire [6:0]  opcode = instruction[6:0];
    wire [4:0]  rd     = instruction[11:7];
    wire [2:0]  funct3 = instruction[14:12];
    wire [4:0]  rs1    = instruction[19:15];
    wire [4:0]  rs2    = instruction[24:20];
    wire [6:0]  funct7 = instruction[31:25];

    // --- Control signals ---
    wire        RegWrite;                // Register file write enable
    wire        ALUSrc;                  // ALU operand B source select
    wire        MemRead;                 // Data memory read enable
    wire        MemWrite;                // Data memory write enable
    wire        ResultSrc;               // Write-back data source select
    wire        Branch;                  // Branch instruction flag
    wire [1:0]  ALUOp;                   // ALU operation category
    wire [1:0]  ImmSrc;                  // Immediate format select

    // --- Datapath signals ---
    wire [31:0] reg_data1;               // Register rs1 value
    wire [31:0] reg_data2;               // Register rs2 value
    wire [31:0] imm_ext;                 // Sign-extended immediate
    wire [31:0] alu_operand_b;           // ALU input B (after mux)
    wire [2:0]  alu_operation;           // ALU control code
    wire [31:0] alu_result;              // ALU output
    wire        zero;                    // ALU zero flag
    wire [31:0] mem_read_data;           // Data memory read output
    wire [31:0] write_back_data;         // Data written to register file

    // --- Branch decision ---
    wire        branch_taken;            // Whether branch condition is met
    wire        PCSrc;                   // Final PC source select

    // --- Gated write enables (suppress writes during reset) ---
    wire        reg_write_en  = RegWrite & ~reset;
    wire        mem_write_en  = MemWrite & ~reset;

    // =========================================================================
    // Output assignments
    // =========================================================================
    assign pc       = pc_current;
    assign pc_plus4 = pc_current + 32'd4;

    // =========================================================================
    // STAGE 1: INSTRUCTION FETCH
    // =========================================================================
    // Task 1: Integrate Program Counter and Instruction Memory
    // The PC feeds its value to Instruction Memory, which outputs the
    // instruction word at that address. Next-PC mux feeds back into PC.
    // =========================================================================

    program_counter u_pc (
        .clk     (clk),
        .reset   (reset),
        .next_pc (next_pc_wire),
        .pc      (pc_current)
    );

    instruction_memory #(
        .DEPTH     (IMEM_DEPTH),
        .INIT_FILE (IMEM_INIT_FILE)
    ) u_imem (
        .address     (pc_current),
        .instruction (instruction)
    );

    // =========================================================================
    // STAGE 2: INSTRUCTION DECODE & CONTROL
    // =========================================================================
    // Task 2: Connect Register File, Immediate Generator, and ALU
    // Task 3: Integrate Main Control Unit and ALU Control Unit
    //
    // The instruction word is decoded by the control unit to produce all
    // control signals. Register addresses (rs1, rs2, rd) are extracted from
    // instruction fields. The immediate generator extracts and sign-extends
    // the immediate based on ImmSrc from control.
    // =========================================================================

    control_unit u_ctrl (
        .opcode   (opcode),
        .funct3   (funct3),
        .funct7   (funct7),
        .RegWrite (RegWrite),
        .ALUSrc   (ALUSrc),
        .MemRead  (MemRead),
        .MemWrite (MemWrite),
        .ResultSrc(ResultSrc),
        .Branch   (Branch),
        .ALUOp    (ALUOp),
        .ImmSrc   (ImmSrc)
    );

    register_file u_regfile (
        .clk        (clk),
        .rs1        (rs1),
        .rs2        (rs2),
        .rd         (rd),
        .write_data (write_back_data),
        .RegWrite   (reg_write_en),
        .read_data1 (reg_data1),
        .read_data2 (reg_data2)
    );

    immediate_generator u_immgen (
        .instruction (instruction),
        .ImmSrc      (ImmSrc),
        .imm_ext     (imm_ext)
    );

    // =========================================================================
    // STAGE 3: EXECUTION
    // =========================================================================
    // The ALU source mux selects between register data (R-type, branch) and
    // immediate (I-type, load, store). The ALU control unit decodes ALUOp +
    // funct3 + funct7[5] to produce the specific ALU operation code.
    // =========================================================================

    alu_src_mux u_alu_mux (
        .reg_data2     (reg_data2),
        .imm_ext       (imm_ext),
        .ALUSrc        (ALUSrc),
        .alu_operand_b (alu_operand_b)
    );

    alu_control u_aluctrl (
        .alu_op      (ALUOp),
        .funct3      (funct3),
        .funct7_bit5 (instruction[30]),
        .operation   (alu_operation)
    );

    alu u_alu (
        .a           (reg_data1),
        .b           (alu_operand_b),
        .alu_control (alu_operation),
        .result      (alu_result),
        .zero        (zero)
    );

    // =========================================================================
    // STAGE 4: DATA MEMORY
    // =========================================================================
    // Task 4: Connect Data Memory and Write-Back logic
    //
    // For LW: ALU computes address (base + offset), data memory reads.
    // For SW: ALU computes address, register rs2 provides store data.
    // Write-back mux selects between ALU result and memory read data.
    // =========================================================================

    data_memory #(
        .DEPTH (DMEM_DEPTH)
    ) u_dmem (
        .clk        (clk),
        .MemRead    (MemRead),
        .MemWrite   (mem_write_en),
        .address    (alu_result),
        .write_data (reg_data2),
        .read_data  (mem_read_data)
    );

    writeback_mux u_wb_mux (
        .alu_result      (alu_result),
        .mem_read_data   (mem_read_data),
        .ResultSrc       (ResultSrc),
        .write_back_data (write_back_data)
    );

    // =========================================================================
    // STAGE 5: BRANCH / NEXT-PC SELECTION
    // =========================================================================
    // Task 5: Integrate Branch Target and Next-PC selection logic
    //
    // Branch target = PC + B-type immediate (computed by branch_target module).
    // Branch decision: Control asserts Branch for BEQ/BNE. funct3[0]
    // distinguishes them:
    //   BEQ (funct3=000): taken when ALU zero=1 (operands equal)
    //   BNE (funct3=001): taken when ALU zero=0 (operands differ)
    // PCSrc = Branch AND branch_taken → selects branch target over PC+4.
    // =========================================================================

    branch_target u_btgt (
        .pc                 (pc_current),
        .imm_ext            (imm_ext),
        .branch_target_addr (branch_addr)
    );

    // Branch condition evaluation
    assign branch_taken = funct3[0] ? ~zero : zero;  // BNE: ~zero, BEQ: zero
    assign PCSrc        = Branch & branch_taken;

    next_pc_mux u_npc_mux (
        .pc_plus4      (pc_plus4),
        .branch_target (branch_addr),
        .PCSrc         (PCSrc),
        .next_pc       (next_pc_wire)
    );

endmodule
