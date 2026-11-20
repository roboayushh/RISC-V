`timescale 1ns/1ps

module tb_memory_depth_one;
    reg         clk = 0;
    reg         read_enable = 1;
    reg         write_enable = 1;
    reg  [31:0] address = 0;
    reg  [31:0] write_data = 32'h12345678;
    wire [31:0] instruction, read_data;

    instruction_memory #(
        .DEPTH(1), .INIT_FILE("programs/one_word_test.hex")
    ) imem (
        .address(address), .instruction(instruction)
    );

    data_memory #(.DEPTH(1)) dmem (
        .clk(clk), .MemRead(read_enable), .MemWrite(write_enable),
        .address(address), .write_data(write_data), .read_data(read_data)
    );

    task read_check;
        input [31:0] expected_instruction, expected_data;
        begin
            #1;
            if ((instruction !== expected_instruction) || (read_data !== expected_data))
                $fatal(1, "addr=%h expected INST=%h DATA=%h, got INST=%h DATA=%h",
                       address, expected_instruction, expected_data, instruction, read_data);
        end
    endtask

    task clock_write;
        begin
            clk = 1;
            #1;
            clk = 0;
        end
    endtask

    initial begin
        $dumpfile("build/tb_memory_depth_one.vcd");
        $dumpvars(0, tb_memory_depth_one);
        read_check(32'h00500093, 32'h0);
        clock_write;
        read_check(32'h00500093, 32'h12345678);

        write_data = 32'hDEADBEEF;
        address = 4;
        read_check(32'h00000013, 32'h0);
        clock_write;
        address = 1;
        read_check(32'h00000013, 32'h0);
        clock_write;

        address = 0;
        read_check(32'h00500093, 32'h12345678);
        read_enable = 0;
        read_check(32'h00500093, 32'h0);
        $display("ONE-WORD MEMORY TEST PASSED");
        $finish;
    end
endmodule
