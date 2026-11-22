`timescale 1ns/1ps

// End-to-end ALU verification in the complete rv32i_top datapath.
// Covers all supported ALU operations, signed immediates, address generation,
// BEQ/BNE equality decisions, 32-bit wraparound, and ALU-control decoding.
module tb_alu_integration;
    reg clk;
    reg reset;
    wire [31:0] pc;
    wire [31:0] instruction;
    wire halted;
    integer errors;
    integer checks;
    integer cycles;

    rv32i_top #(
        .IMEM_DEPTH(25),
        .IMEM_INIT_FILE("programs/alu_integration.hex"),
        .DMEM_DEPTH(256)
    ) dut (
        .clk(clk),
        .reset(reset),
        .pc_out(pc),
        .instr_out(instruction),
        .halted(halted)
    );

    always #5 clk = ~clk;

    task check_value;
        input [511:0] label;
        input [31:0] actual;
        input [31:0] expected;
        begin
            checks = checks + 1;
            if (actual !== expected) begin
                $display("FAIL | %-0s | expected=0x%08h actual=0x%08h",
                         label, expected, actual);
                errors = errors + 1;
            end else begin
                $display("PASS | %-0s | 0x%08h", label, actual);
            end
        end
    endtask

    // Check internal combinational control/result signals while the specified
    // instruction is active. These checks prove decoding inside the integrated
    // processor, not merely the final architectural register values.
    task check_execute_signals;
        input [511:0] label;
        input [2:0] expected_operation;
        input [31:0] expected_result;
        begin
            check_value({label, " ALU control"},
                        {29'b0, dut.u_core.alu_operation},
                        {29'b0, expected_operation});
            check_value({label, " ALU result"}, dut.u_core.alu_result,
                        expected_result);
        end
    endtask

    initial begin
        $dumpfile("build/tb_alu_integration.vcd");
        $dumpvars(0, tb_alu_integration);

        clk = 1'b0;
        reset = 1'b1;
        errors = 0;
        checks = 0;
        cycles = 0;

        // Seed values that cannot be constructed with this project's ten-
        // instruction subset (LUI is intentionally unsupported). They allow
        // the integrated ALU/write-back path to exercise signed boundaries.
        repeat (2) @(posedge clk);
        dut.u_core.u_regfile.registers[20] = 32'h7fffffff;
        dut.u_core.u_regfile.registers[22] = 32'h80000000;
        @(negedge clk);
        reset = 1'b0;

        // PC=0 is already active at reset release, so sample its control path
        // before advancing to the first rising execution edge.
        #1;
        check_execute_signals("ADDI positive", 3'b000, 32'd1);
        check_value("ADDI selects immediate", {31'b0, dut.u_core.ALUSrc}, 32'd1);

        while (!halted && cycles < 50) begin
            // Sample midway through the cycle, after the combinational path has
            // settled and before the next architectural write.
            @(negedge clk);
            cycles = cycles + 1;
            case (pc)
                32'd4:  check_execute_signals("ADDI negative", 3'b000, 32'hffffffff);
                32'd8:  check_execute_signals("ADD", 3'b000, 32'd0);
                32'd12: check_execute_signals("SUB", 3'b001, 32'd2);
                32'd16: check_execute_signals("AND", 3'b010, 32'd1);
                32'd20: check_execute_signals("OR", 3'b011, 32'hffffffff);
                32'd24: check_execute_signals("XOR", 3'b100, 32'hfffffffe);
                32'd28: check_execute_signals("ADD wraparound", 3'b000, 32'hfffffffe);
                32'd32: check_execute_signals("signed max plus one", 3'b000, 32'h80000000);
                32'd36: check_execute_signals("signed min minus one", 3'b001, 32'h7fffffff);
                32'd44: begin
                    check_execute_signals("SW address +4", 3'b000, 32'd68);
                    check_value("SW write enable", {31'b0, dut.u_core.MemWrite}, 32'd1);
                end
                32'd48: begin
                    check_execute_signals("LW address +4", 3'b000, 32'd68);
                    check_value("LW read enable", {31'b0, dut.u_core.MemRead}, 32'd1);
                    check_value("LW memory writeback selected", {31'b0, dut.u_core.ResultSrc}, 32'd1);
                end
                32'd52: check_execute_signals("SW address -4", 3'b000, 32'd60);
                32'd56: check_execute_signals("LW address -4", 3'b000, 32'd60);
                32'd60: begin
                    check_execute_signals("BEQ equal compare", 3'b001, 32'd0);
                    check_value("BEQ equal taken", {31'b0, dut.u_core.PCSrc}, 32'd1);
                end
                32'd72: begin
                    check_execute_signals("BNE equal compare", 3'b001, 32'd0);
                    check_value("BNE equal not taken", {31'b0, dut.u_core.PCSrc}, 32'd0);
                end
                32'd80: begin
                    check_execute_signals("BNE unequal compare", 3'b001, 32'd2);
                    check_value("BNE unequal taken", {31'b0, dut.u_core.PCSrc}, 32'd1);
                end
                32'd88: begin
                    check_execute_signals("BEQ unequal compare", 3'b001, 32'd2);
                    check_value("BEQ unequal not taken", {31'b0, dut.u_core.PCSrc}, 32'd0);
                end
                default: begin end
            endcase
        end

        if (!halted) begin
            $display("FAIL | processor did not reach halt loop");
            errors = errors + 1;
        end

        $display("\n--- Final architectural state ---");
        check_value("x1 positive ADDI", dut.u_core.u_regfile.registers[1], 32'd1);
        check_value("x2 negative ADDI", dut.u_core.u_regfile.registers[2], 32'hffffffff);
        check_value("x3 ADD", dut.u_core.u_regfile.registers[3], 32'd0);
        check_value("x4 SUB", dut.u_core.u_regfile.registers[4], 32'd2);
        check_value("x5 AND", dut.u_core.u_regfile.registers[5], 32'd1);
        check_value("x6 OR", dut.u_core.u_regfile.registers[6], 32'hffffffff);
        check_value("x7 XOR", dut.u_core.u_regfile.registers[7], 32'hfffffffe);
        check_value("x8 modular overflow", dut.u_core.u_regfile.registers[8], 32'hfffffffe);
        check_value("x9 0x7fffffff + 1", dut.u_core.u_regfile.registers[9], 32'h80000000);
        check_value("x10 0x80000000 - 1", dut.u_core.u_regfile.registers[10], 32'h7fffffff);
        check_value("mem[17] positive-offset address", dut.u_core.u_dmem.memory[17], 32'd2);
        check_value("x12 LW positive offset", dut.u_core.u_regfile.registers[12], 32'd2);
        check_value("mem[15] negative-offset address", dut.u_core.u_dmem.memory[15], 32'hfffffffe);
        check_value("x13 LW negative offset", dut.u_core.u_regfile.registers[13], 32'hfffffffe);
        check_value("x14 skipped by BEQ", dut.u_core.u_regfile.registers[14], 32'd0);
        check_value("x15 BEQ target", dut.u_core.u_regfile.registers[15], 32'd7);
        check_value("x16 BNE equal fall-through", dut.u_core.u_regfile.registers[16], 32'd8);
        check_value("x17 skipped by BNE", dut.u_core.u_regfile.registers[17], 32'd0);
        check_value("x18 BEQ unequal fall-through", dut.u_core.u_regfile.registers[18], 32'd9);

        if (errors == 0) begin
            $display("\nALU INTEGRATION TEST PASSED (%0d checks)", checks);
            $finish;
        end else begin
            $display("\nALU INTEGRATION TEST FAILED (%0d errors / %0d checks)", errors, checks);
            $fatal(1);
        end
    end
endmodule
