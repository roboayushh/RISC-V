`timescale 1ns/1ps

// Expected retirements are specified by the test program, independently of
// the decoder. Sample after the rising edge to include nonblocking writes.
module tb_final_verification;
    localparam WORDS = 32;
    reg clk = 0;
    reg reset = 1;
    wire [31:0] pc, instruction;
    reg [31:0] expected_regs [0:31];
    reg [31:0] expected_mem [0:WORDS-1];
    integer i, retired = 0;

    rv32i_core #(.IMEM_DEPTH(25), .DMEM_DEPTH(WORDS),
                 .IMEM_INIT_FILE("programs/final_verification.hex"))
        dut (.clk(clk), .reset(reset), .pc(pc), .instruction(instruction));

    always #5 clk = ~clk;

    task check_state;
        integer j;
        begin
            for (j = 0; j < 32; j = j + 1)
                if (dut.u_regfile.registers[j] !== expected_regs[j])
                    $fatal(1, "PC=%h x%0d expected=%h got=%h", pc, j,
                           expected_regs[j], dut.u_regfile.registers[j]);
            for (j = 0; j < WORDS; j = j + 1)
                if (dut.u_dmem.memory[j] !== expected_mem[j])
                    $fatal(1, "PC=%h memory[%0d] expected=%h got=%h", pc, j,
                           expected_mem[j], dut.u_dmem.memory[j]);
        end
    endtask

    task step;
        input [31:0] address, destination;
        begin
            if (pc !== address)
                $fatal(1, "Expected instruction at %h, got PC=%h", address, pc);
            if (address >= 'h3c && address <= 'h54 &&
                {dut.reg_write_en, dut.mem_write_en, dut.MemRead, dut.PCSrc} !== 4'b0)
                $fatal(1, "Unsupported encoding %h at %h enabled a side effect", instruction, pc);
            @(posedge clk);
            #1;
            if (pc !== destination)
                $fatal(1, "After PC=%h expected PC=%h, got %h", address, destination, pc);
            check_state;
            retired = retired + 1;
        end
    endtask

    initial begin
        $dumpfile("build/tb_final_verification.vcd");
        $dumpvars(0, tb_final_verification);
        for (i = 0; i < 32; i = i + 1) expected_regs[i] = 0;
        for (i = 0; i < WORDS; i = i + 1) expected_mem[i] = 0;
        repeat (2) @(posedge clk);
        #1;
        check_state;
        @(negedge clk);
        reset = 0;
        expected_regs[1] = 64; step('h00, 'h04);
        expected_regs[2] = -7; step('h04, 'h08);
        expected_mem[16] = -7; step('h08, 'h0c);
        expected_regs[3] = -7; step('h0c, 'h10);
        expected_regs[4] = -14; step('h10, 'h14);
        step('h14, 'h18); // SUB produces zero.
        expected_regs[6] = -7; step('h18, 'h1c);
        expected_regs[7] = 64; step('h1c, 'h20);
        step('h20, 'h24); // XOR produces zero.
        step('h24, 'h2c);
        step('h2c, 'h30);
        expected_regs[9] = 1; step('h30, 'h34);
        step('h34, 'h3c);
        for (i = 'h3c; i <= 'h54; i = i + 4)
            step(i, i + 4);
        expected_regs[10] = -7; step('h58, 'h5c);
        step('h5c, 'h60);
        step('h60, 'h60);
        $display("FINAL PROCESSOR TEST PASSED (%0d retirements, 7 unsupported encodings)", retired);
        $finish;
    end
endmodule
