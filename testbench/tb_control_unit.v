`timescale 1ns/1ps

module tb_control_unit;
    reg  [31:0] instruction;
    wire        RegWrite, ALUSrc, MemRead, MemWrite, ResultSrc, Branch;
    wire [1:0]  ALUOp, ImmSrc;
    wire [2:0]  operation;
    wire [31:0] imm_ext;
    wire [9:0]  controls;
    integer tests;

    assign controls = {RegWrite, ALUSrc, MemRead, MemWrite, ResultSrc,
                       Branch, ALUOp, ImmSrc};

    control_unit dut (
        .opcode(instruction[6:0]),
        .funct3(instruction[14:12]),
        .funct7(instruction[31:25]),
        .RegWrite(RegWrite),
        .ALUSrc(ALUSrc),
        .MemRead(MemRead),
        .MemWrite(MemWrite),
        .ResultSrc(ResultSrc),
        .Branch(Branch),
        .ALUOp(ALUOp),
        .ImmSrc(ImmSrc)
    );

    alu_control alu_decoder (
        .alu_op(ALUOp),
        .funct3(instruction[14:12]),
        .funct7_bit5(instruction[30]),
        .operation(operation)
    );

    immediate_generator imm_decoder (
        .instruction(instruction),
        .ImmSrc(ImmSrc),
        .imm_ext(imm_ext)
    );

    task check;
        input [31:0] word;
        input [9:0]  expected_controls;
        input [2:0]  expected_operation;
        input [31:0] expected_immediate;
        begin
            instruction = word;
            #1;
            if ((controls !== expected_controls) ||
                (operation !== expected_operation) ||
                (imm_ext !== expected_immediate)) begin
                $display("FAIL: instruction=%08h", word);
                $display("  controls=%b expected=%b", controls, expected_controls);
                $display("  ALU operation=%b expected=%b", operation, expected_operation);
                $display("  immediate=%08h expected=%08h", imm_ext, expected_immediate);
                $fatal(1);
            end
            tests = tests + 1;
        end
    endtask

    initial begin
        tests = 0;
        $dumpfile("build/tb_control_unit.vcd");
        $dumpvars(0, tb_control_unit);

        // Control vector: {RegWrite, ALUSrc, MemRead, MemWrite, ResultSrc, Branch, ALUOp, ImmSrc}
        check(32'h002081b3, 10'b100000_10_11, 3'b000, 32'd0); // ADD
        check(32'h40208233, 10'b100000_10_11, 3'b001, 32'd0); // SUB
        check(32'h0020f2b3, 10'b100000_10_11, 3'b010, 32'd0); // AND
        check(32'h0020e333, 10'b100000_10_11, 3'b011, 32'd0); // OR
        check(32'h0020c3b3, 10'b100000_10_11, 3'b100, 32'd0); // XOR
        check(32'h4020c3b3, 10'b000000_11_11, 3'b111, 32'd0); // Invalid XOR funct7
        check(32'h022081b3, 10'b000000_11_11, 3'b111, 32'd0); // Unsupported MUL
        check(32'h002091b3, 10'b000000_11_11, 3'b111, 32'd0); // Unsupported SLL

        check(32'h00a00093, 10'b110000_00_00, 3'b000, 32'd10); // ADDI +10
        check(32'hfff00093, 10'b110000_00_00, 3'b000, -32'd1); // ADDI -1
        check(32'h00000013, 10'b110000_00_00, 3'b000, 32'd0); // NOP (ADDI x0, x0, 0)
        check(32'h0020e193, 10'b000000_11_11, 3'b111, 32'd0); // Unsupported ORI

        check(32'hffc0a183, 10'b111010_00_00, 3'b000, -32'd4); // LW -4
        check(32'hffc08183, 10'b000000_11_11, 3'b111, 32'd0); // Unsupported LB
        check(32'h0020a623, 10'b010100_00_01, 3'b000, 32'd12); // SW +12
        check(32'h00208623, 10'b000000_11_11, 3'b111, 32'd0); // Unsupported SB

        check(32'h00208463, 10'b000001_01_10, 3'b001, 32'd8); // BEQ +8
        check(32'hfe209ee3, 10'b000001_01_10, 3'b001, -32'd4); // BNE -4
        check(32'h0020c463, 10'b000000_11_11, 3'b111, 32'd0); // Unsupported BLT
        check(32'hffffffff, 10'b000000_11_11, 3'b111, 32'd0); // Unsupported opcode

        $display("CONTROL UNIT TEST PASSED (%0d cases)", tests);
        $finish;
    end
endmodule
