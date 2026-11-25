`timescale 1ns/1ps

// =============================================================================
// Full single-cycle RV32I core (Milestone 10).
//
// Integrates the complete datapath for all ten supported instructions:
//   ADD, SUB, AND, OR, XOR, ADDI, LW, SW, BEQ, BNE.
//
// Compared with rv32i_phase1_core.v (arithmetic-only), this core adds:
//   - Data memory for LW/SW.
//   - Write-back mux (ALU result vs. loaded data).
//   - Branch target + next-PC mux so taken branches redirect the PC.
//   - Branch decision: PCSrc = Branch AND (BEQ: zero, BNE: !zero).
//
// The PC is driven directly here (not via the fetch scaffold) so the next-PC
// mux can select between PC+4 and the branch target.
// =============================================================================
module rv32i_core_full #(
    parameter IMEM_DEPTH      = 11,
    parameter IMEM_INIT_FILE  = "programs/full_demo.hex",
    parameter DMEM_DEPTH      = 256,
    parameter IMEM_WORDS = IMEM_DEPTH
) (
    input  wire        clk,
    input  wire        reset,
    output wire [31:0] pc,
    output wire [31:0] instruction
);

    // ----------------------------------------------------------------- Fetch
    wire [31:0] pc_current, pc_plus4, branch_addr, next_pc;

    program_counter pc_unit (
        .clk     (clk),
        .reset   (reset),
        .next_pc (next_pc),
        .pc      (pc_current)
    );

    assign pc       = pc_current;
    assign pc_plus4 = pc_current + 32'd4;

    instruction_memory #(
        .DEPTH     (IMEM_DEPTH),
        .INIT_FILE (IMEM_INIT_FILE),
        .INIT_WORDS(IMEM_WORDS)
    ) imem (
        .address     (pc_current),
        .instruction (instruction)
    );

    // ---------------------------------------------------------------- Decode
    wire [6:0] opcode = instruction[6:0];
    wire [2:0] funct3 = instruction[14:12];
    wire [6:0] funct7 = instruction[31:25];
    wire [4:0] rs1    = instruction[19:15];
    wire [4:0] rs2    = instruction[24:20];
    wire [4:0] rd     = instruction[11:7];

    wire       RegWrite, ALUSrc, MemRead, MemWrite, ResultSrc, Branch;
    wire [1:0] ALUOp, ImmSrc;

    control_unit ctrl (
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

    // ------------------------------------------------------------- Execute
    wire [31:0] reg_data1, reg_data2, imm_ext, alu_operand_b, alu_result;
    wire [31:0] mem_read_data, write_back_data;
    wire [2:0]  alu_operation;
    wire        zero;

    // Writes are suppressed during reset so no architectural state changes.
    wire reg_write_gated = RegWrite && !reset;
    wire mem_write_gated = MemWrite && !reset;

    register_file rf (
        .clk        (clk),
        .rs1        (rs1),
        .rs2        (rs2),
        .rd         (rd),
        .write_data (write_back_data),
        .RegWrite   (reg_write_gated),
        .read_data1 (reg_data1),
        .read_data2 (reg_data2)
    );

    immediate_generator immgen (
        .instruction (instruction),
        .ImmSrc      (ImmSrc),
        .imm_ext     (imm_ext)
    );

    alu_src_mux b_mux (
        .reg_data2     (reg_data2),
        .imm_ext       (imm_ext),
        .ALUSrc        (ALUSrc),
        .alu_operand_b (alu_operand_b)
    );

    alu_control aluctrl (
        .alu_op      (ALUOp),
        .funct3      (funct3),
        .funct7_bit5 (instruction[30]),
        .operation   (alu_operation)
    );

    alu alu_u (
        .a           (reg_data1),
        .b           (alu_operand_b),
        .alu_control (alu_operation),
        .result      (alu_result),
        .zero        (zero)
    );

    // -------------------------------------------------------------- Memory
    data_memory #(
        .DEPTH (DMEM_DEPTH)
    ) dmem (
        .clk        (clk),
        .MemRead    (MemRead),
        .MemWrite   (mem_write_gated),
        .address    (alu_result),
        .write_data (reg_data2),
        .read_data  (mem_read_data)
    );

    // ----------------------------------------------------------- Write-back
    writeback_mux wb_mux (
        .alu_result      (alu_result),
        .mem_read_data   (mem_read_data),
        .ResultSrc       (ResultSrc),
        .write_back_data (write_back_data)
    );

    // ------------------------------------------------------ Branch / next PC
    branch_target btgt (
        .pc                 (pc_current),
        .imm_ext            (imm_ext),
        .branch_target_addr (branch_addr)
    );

    // Branch decision: the control unit asserts Branch for BEQ/BNE. funct3[0]
    // distinguishes them (BEQ=000, BNE=001). BEQ is taken when operands are
    // equal (ALU zero = 1); BNE is taken when they differ (zero = 0).
    wire branch_taken = funct3[0] ? ~zero : zero;
    wire PCSrc        = Branch && branch_taken;

    next_pc_mux npc_mux (
        .pc_plus4      (pc_plus4),
        .branch_target (branch_addr),
        .PCSrc         (PCSrc),
        .next_pc       (next_pc)
    );

endmodule
