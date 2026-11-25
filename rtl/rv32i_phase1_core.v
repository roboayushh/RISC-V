`timescale 1ns/1ps

// Phase 1 arithmetic datapath with sequential instruction fetch.
module rv32i_phase1_core #(
    parameter IMEM_DEPTH = 14,
    parameter IMEM_INIT_FILE = "programs/phase1_arithmetic.hex",
    parameter IMEM_WORDS = IMEM_DEPTH
) (
    input  wire        clk,
    input  wire        reset,
    output wire [31:0] pc,
    output wire [31:0] instruction
);
    wire [4:0]  rs1 = instruction[19:15];
    wire [4:0]  rs2 = instruction[24:20];
    wire [4:0]  rd  = instruction[11:7];
    wire [31:0] reg_data1, reg_data2, imm_ext, alu_operand_b, alu_result;
    wire [2:0]  alu_operation;
    wire [1:0]  alu_op, imm_src;
    wire        reg_write, alu_src, result_src, write_enable;
    wire        unused_mem_read, unused_mem_write, unused_branch, unused_zero;
    wire [31:0] next_pc;

    // Phase 1 writes ALU results only. Loads request memory writeback.
    assign write_enable = !reset && reg_write && !result_src;

    // Keep the Phase 1 wrapper independent of the Phase 2 full core. The old
    // version instantiated rv32i_core when that name referred to a fetch-only
    // scaffold; rv32i_core is now the complete processor and must not be nested
    // here as a second executing datapath.
    assign next_pc = pc + 32'd4;

    program_counter pc_unit (
        .clk(clk),
        .reset(reset),
        .next_pc(next_pc),
        .pc(pc)
    );

    instruction_memory #(
        .DEPTH(IMEM_DEPTH),
        .INIT_FILE(IMEM_INIT_FILE),
        .INIT_WORDS(IMEM_WORDS)
    ) imem (
        .address(pc),
        .instruction(instruction)
    );

    control_unit decoder (
        .opcode(instruction[6:0]),
        .funct3(instruction[14:12]),
        .funct7(instruction[31:25]),
        .RegWrite(reg_write),
        .ALUSrc(alu_src),
        .MemRead(unused_mem_read),
        .MemWrite(unused_mem_write),
        .ResultSrc(result_src),
        .Branch(unused_branch),
        .ALUOp(alu_op),
        .ImmSrc(imm_src)
    );

    register_file register_file_unit (
        .clk(clk),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .write_data(alu_result),
        .RegWrite(write_enable),
        .read_data1(reg_data1),
        .read_data2(reg_data2)
    );

    immediate_generator immediate_decoder (
        .instruction(instruction),
        .ImmSrc(imm_src),
        .imm_ext(imm_ext)
    );

    alu_src_mux operand_mux (
        .reg_data2(reg_data2),
        .imm_ext(imm_ext),
        .ALUSrc(alu_src),
        .alu_operand_b(alu_operand_b)
    );

    alu_control operation_decoder (
        .alu_op(alu_op),
        .funct3(instruction[14:12]),
        .funct7_bit5(instruction[30]),
        .operation(alu_operation)
    );

    alu execution (
        .a(reg_data1),
        .b(alu_operand_b),
        .alu_control(alu_operation),
        .result(alu_result),
        .zero(unused_zero)
    );
endmodule
