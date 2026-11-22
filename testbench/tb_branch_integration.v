`timescale 1ns/1ps

// M13 directed branch/PC checks and assembly workload execution.
// Implemented by Samiksha Jangid for Saumya's Phase 2 work package.
// The expected PC routes and branch offsets below are authored independently
// of the DUT. Every architectural check occurs after nonblocking writes settle.
module tb_branch_integration;
    parameter PROGRAM_ID = 0;
    localparam PROGRAM_NAME =
        (PROGRAM_ID == 0) ? "arithmetic" :
        (PROGRAM_ID == 1) ? "memory" :
        (PROGRAM_ID == 2) ? "branch_equal" :
        (PROGRAM_ID == 3) ? "branch_not_equal" :
        (PROGRAM_ID == 4) ? "integration" : "branch_offsets";
    localparam PROGRAM_FILE =
        (PROGRAM_ID == 0) ? "programs/arithmetic.hex" :
        (PROGRAM_ID == 1) ? "programs/memory.hex" :
        (PROGRAM_ID == 2) ? "programs/branch_equal.hex" :
        (PROGRAM_ID == 3) ? "programs/branch_not_equal.hex" :
        (PROGRAM_ID == 4) ? "programs/integration.hex" : "programs/branch_offsets.hex";
    localparam IMEM_WORDS =
        (PROGRAM_ID == 0) ? 15 : (PROGRAM_ID == 1) ? 11 :
        (PROGRAM_ID == 2) ? 16 : (PROGRAM_ID == 3) ? 13 :
        (PROGRAM_ID == 4) ? 22 : 1028;

    reg clk = 1'b0;
    reg reset = 1'b1;
    wire [31:0] pc;
    wire [31:0] instruction;
    wire halted;
    reg [31:0] expected_pc [0:63];
    reg expected_taken [0:63];
    reg [31:0] expected_offset [0:63];
    reg [31:0] expected_registers [0:31];
    reg [31:0] expected_memory [0:31];
    reg [31:0] expected_next;
    reg [31:0] completion_pc;
    reg [2047:0] output_path;
    integer steps;
    integer step;
    integer index;
    integer checks;
    integer trace_file;
    integer beq_taken;
    integer beq_not_taken;
    integer bne_taken;
    integer bne_not_taken;
    integer expected_beq_taken;
    integer expected_beq_not_taken;
    integer expected_bne_taken;
    integer expected_bne_not_taken;

    rv32i_top #(
        .IMEM_DEPTH(IMEM_WORDS),
        .IMEM_INIT_FILE(PROGRAM_FILE),
        .DMEM_DEPTH(32)
    ) dut (
        .clk(clk), .reset(reset), .pc_out(pc),
        .instr_out(instruction), .halted(halted)
    );

    always #5 clk = ~clk;

    task expect_step;
        input [31:0] address;
        input taken;
        input [31:0] offset;
        begin
            expected_pc[steps] = address;
            expected_taken[steps] = taken;
            expected_offset[steps] = offset;
            steps = steps + 1;
        end
    endtask

    task check_value;
        input [511:0] label;
        input [31:0] actual;
        input [31:0] expected;
        begin
            checks = checks + 1;
            if (actual !== expected) begin
                $display("FAIL %0s step=%0d pc=%08h %0s expected=%08h actual=%08h",
                         PROGRAM_NAME, step, pc, label, expected, actual);
                $fatal(1);
            end
        end
    endtask

    initial begin
        if (PROGRAM_ID < 0 || PROGRAM_ID > 5)
            $fatal(1, "PROGRAM_ID must be between 0 and 5");
        steps = 0;
        step = 0;
        checks = 0;
        beq_taken = 0;
        beq_not_taken = 0;
        bne_taken = 0;
        bne_not_taken = 0;
        expected_beq_taken = 0;
        expected_beq_not_taken = 0;
        expected_bne_taken = 0;
        expected_bne_not_taken = 0;
        for (index = 0; index < 32; index = index + 1) begin
            expected_registers[index] = 32'd0;
            expected_memory[index] = 32'd0;
        end

        case (PROGRAM_ID)
            0: begin
                for (index = 0; index < 14; index = index + 1)
                    expect_step(index * 4, 1'b0, 32'd0);
                expect_step(32'd56, 1'b1, 32'd0);
                expected_registers[1] = 10;
                expected_registers[2] = 20;
                expected_registers[3] = 30;
                expected_registers[4] = 10;
                expected_registers[6] = 30;
                expected_registers[7] = 30;
                expected_registers[8] = 32'hffffffff;
                expected_registers[10] = 12;
                expected_registers[11] = 10;
                expected_registers[12] = 8;
                expected_registers[13] = 14;
                expected_registers[14] = 6;
            end
            1: begin
                for (index = 0; index < 10; index = index + 1)
                    expect_step(index * 4, 1'b0, 32'd0);
                expect_step(32'd40, 1'b1, 32'd0);
                expected_registers[1] = 64;
                expected_registers[2] = 25;
                expected_registers[3] = 25;
                expected_registers[4] = 50;
                expected_registers[5] = 50;
                expected_registers[6] = 72;
                expected_registers[7] = 50;
                expected_memory[16] = 25;
                expected_memory[17] = 50;
            end
            2: begin
                expect_step(0, 0, 0);
                expect_step(4, 0, 0);
                expect_step(8, 1, 12);
                expect_step(20, 0, 0);
                expect_step(24, 0, 0);
                expect_step(28, 0, -8);
                expect_step(32, 0, 0);
                expect_step(36, 0, 0);
                expect_step(40, 0, 12);
                expect_step(44, 1, -8);
                expect_step(36, 0, 0);
                expect_step(40, 0, 12);
                expect_step(44, 1, -8);
                expect_step(36, 0, 0);
                expect_step(40, 1, 12);
                expect_step(52, 0, 0);
                expect_step(56, 1, 4);
                expect_step(60, 1, 0);
                expected_registers[1] = 10;
                expected_registers[2] = 10;
                expected_registers[4] = 20;
                expected_registers[6] = 7;
                expected_beq_taken = 5;
                expected_beq_not_taken = 4;
            end
            3: begin
                expect_step(0, 0, 0);
                expect_step(4, 0, 0);
                expect_step(8, 1, 12);
                expect_step(20, 0, 0);
                expect_step(24, 0, 0);
                expect_step(28, 0, 0);
                expect_step(32, 0, 0);
                expect_step(36, 1, -4);
                expect_step(32, 0, 0);
                expect_step(36, 1, -4);
                expect_step(32, 0, 0);
                expect_step(36, 0, -4);
                expect_step(40, 0, 0);
                expect_step(44, 1, 4);
                expect_step(48, 1, 0);
                expected_registers[1] = 10;
                expected_registers[2] = 20;
                expected_registers[4] = 30;
                expected_registers[6] = 7;
                expected_bne_taken = 4;
                expected_bne_not_taken = 2;
            end
            4: begin
                expect_step(0, 0, 0);
                expect_step(4, 0, 0);
                expect_step(8, 0, 0);
                repeat (2) begin
                    expect_step(12, 0, 0);
                    expect_step(16, 0, 0);
                    expect_step(20, 1, -8);
                end
                expect_step(12, 0, 0);
                expect_step(16, 0, 0);
                expect_step(20, 0, -8);
                expect_step(24, 0, 0);
                expect_step(28, 0, 0);
                expect_step(32, 0, 0);
                expect_step(36, 0, 0);
                expect_step(40, 0, 0);
                expect_step(44, 0, 0);
                expect_step(48, 1, 12);
                expect_step(60, 0, 0);
                expect_step(64, 0, 16);
                expect_step(68, 0, 0);
                expect_step(72, 1, 12);
                expect_step(84, 1, 0);
                expected_registers[2] = 6;
                expected_registers[3] = 64;
                expected_registers[4] = 6;
                expected_registers[6] = 6;
                expected_registers[7] = 6;
                expected_registers[10] = 1;
                expected_registers[11] = 42;
                expected_memory[16] = 6;
                expected_beq_taken = 2;
                expected_bne_taken = 2;
                expected_bne_not_taken = 2;
            end
            5: begin
                expect_step(0, 0, 0);
                expect_step(4, 1, 4092);
                expect_step(4096, 0, 0);
                expect_step(4100, 1, -4096);
                expect_step(4, 1, 4092);
                expect_step(4096, 0, 0);
                expect_step(4100, 0, -4096);
                expect_step(4104, 0, 0);
                expect_step(4108, 1, 0);
                expected_registers[3] = 7;
                expected_beq_taken = 2;
                expected_bne_taken = 1;
                expected_bne_not_taken = 1;
            end
        endcase
        completion_pc = expected_pc[steps - 1];

        $sformat(output_path, "build/branch/%0s.vcd", PROGRAM_NAME);
        $dumpfile(output_path);
        $dumpvars(0, clk, reset, pc, instruction, halted);
        $dumpvars(1, dut.u_core);
        $sformat(output_path, "build/branch/%0s.csv", PROGRAM_NAME);
        trace_file = $fopen(output_path, "w");
        if (trace_file == 0)
            $fatal(1, "Cannot open trace output; create build/branch first");
        $fdisplay(trace_file, "step,time_ns,pc,instruction,imm_ext,zero,PCSrc,branch_target,next_pc,RegWrite,MemWrite");

        repeat (2) @(posedge clk);
        #1;
        check_value("reset PC", pc, 0);
        @(negedge clk);
        reset = 1'b0;

        for (step = 0; step < steps; step = step + 1) begin
            #1;
            expected_next = completion_pc;
            if (step + 1 < steps)
                expected_next = expected_pc[step + 1];
            check_value("instruction PC", pc, expected_pc[step]);
            check_value("PCSrc", {31'b0, dut.u_core.PCSrc}, {31'b0, expected_taken[step]});
            check_value("selected next PC", dut.u_core.next_pc_wire, expected_next);

            if (instruction[6:0] == 7'b1100011) begin
                check_value("B immediate", dut.u_core.imm_ext, expected_offset[step]);
                check_value("branch address", dut.u_core.branch_addr, pc + expected_offset[step]);
                check_value("branch register write disabled", {31'b0, dut.u_core.reg_write_en}, 0);
                check_value("branch memory write disabled", {31'b0, dut.u_core.mem_write_en}, 0);
                if (instruction[14:12] == 3'b000)
                    check_value("BEQ zero flag", {31'b0, dut.u_core.zero}, {31'b0, expected_taken[step]});
                else
                    check_value("BNE zero flag", {31'b0, dut.u_core.zero}, {31'b0, ~expected_taken[step]});

                // Exclude the completion self-loop from functional coverage.
                if (pc != completion_pc) begin
                    case ({instruction[14:12], expected_taken[step]})
                        4'b0001: beq_taken = beq_taken + 1;
                        4'b0000: beq_not_taken = beq_not_taken + 1;
                        4'b0011: bne_taken = bne_taken + 1;
                        4'b0010: bne_not_taken = bne_not_taken + 1;
                        default: $fatal(1, "Unexpected branch encoding");
                    endcase
                end
            end

            $fdisplay(trace_file, "%0d,%0d,%08h,%08h,%08h,%b,%b,%08h,%08h,%b,%b",
                      step, $time, pc, instruction, dut.u_core.imm_ext,
                      dut.u_core.zero, dut.u_core.PCSrc, dut.u_core.branch_addr,
                      dut.u_core.next_pc_wire, dut.u_core.reg_write_en, dut.u_core.mem_write_en);
            @(posedge clk);
            #1;
            check_value("committed PC", pc, expected_next);
            @(negedge clk);
        end

        // The wrapper's halted output observes a repeated PC. The terminal
        // BEQ continues executing, so allow its observation latency explicitly.
        repeat (2) begin
            @(posedge clk);
            #1;
            check_value("completion self-loop", pc, completion_pc);
            @(negedge clk);
        end
        check_value("completion observed", {31'b0, halted}, 1);
        for (index = 0; index < 32; index = index + 1) begin
            if (dut.u_core.u_regfile.registers[index] !== expected_registers[index]) begin
                $display("FAIL %0s x%0d expected=%08h actual=%08h", PROGRAM_NAME,
                         index, expected_registers[index], dut.u_core.u_regfile.registers[index]);
                $fatal(1);
            end
            checks = checks + 1;
            if (dut.u_core.u_dmem.memory[index] !== expected_memory[index]) begin
                $display("FAIL %0s memory byte=%0d expected=%08h actual=%08h", PROGRAM_NAME,
                         index * 4, expected_memory[index], dut.u_core.u_dmem.memory[index]);
                $fatal(1);
            end
            checks = checks + 1;
        end
        check_value("BEQ taken coverage", beq_taken, expected_beq_taken);
        check_value("BEQ not-taken coverage", beq_not_taken, expected_beq_not_taken);
        check_value("BNE taken coverage", bne_taken, expected_bne_taken);
        check_value("BNE not-taken coverage", bne_not_taken, expected_bne_not_taken);
        $fclose(trace_file);
        $display("BRANCH PROGRAM PASSED: %0s (%0d steps, %0d checks)", PROGRAM_NAME, steps, checks);
        $display("BRANCH COVERAGE: BEQ taken=%0d not_taken=%0d BNE taken=%0d not_taken=%0d",
                 beq_taken, beq_not_taken, bne_taken, bne_not_taken);
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "Branch/PC test exceeded the simulation time limit");
    end
endmodule
