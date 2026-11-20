`timescale 1ns/1ps

// Self-checking testbench for the 256 x 32-bit data memory.
module tb_data_memory;

    reg         clk;
    reg         MemRead, MemWrite;
    reg  [31:0] address, write_data;
    wire [31:0] read_data;
    integer     errors;

    data_memory dut (
        .clk        (clk),
        .MemRead    (MemRead),
        .MemWrite   (MemWrite),
        .address    (address),
        .write_data (write_data),
        .read_data  (read_data)
    );

    always #5 clk = ~clk;

    // Synchronous store to a byte address.
    task do_store;
        input [31:0] addr;
        input [31:0] data;
        input        wen;
        begin
            @(negedge clk);
            address    = addr;
            write_data = data;
            MemWrite   = wen;
            MemRead    = 1'b0;
            @(posedge clk); // write commits here
            @(negedge clk);
            MemWrite   = 1'b0;
        end
    endtask

    // Asynchronous load with MemRead asserted; compare against expected.
    task check_load;
        input [31:0] addr;
        input [31:0] expected;
        begin
            address = addr;
            MemRead = 1'b1;
            #1;
            if (read_data !== expected) begin
                $display("FAIL: load addr=0x%08h expected=0x%08h got=0x%08h",
                         addr, expected, read_data);
                errors = errors + 1;
            end else begin
                $display("PASS: load addr=0x%08h data=0x%08h", addr, read_data);
            end
            MemRead = 1'b0;
        end
    endtask

    // Check read_data while MemRead is deasserted (must be zero).
    task check_read_disabled;
        input [31:0] addr;
        begin
            address = addr;
            MemRead = 1'b0;
            #1;
            if (read_data !== 32'h00000000) begin
                $display("FAIL: MemRead=0 addr=0x%08h expected=0x00000000 got=0x%08h",
                         addr, read_data);
                errors = errors + 1;
            end else begin
                $display("PASS: MemRead=0 addr=0x%08h read_data=0x%08h", addr, read_data);
            end
        end
    endtask

    initial begin
        $dumpfile("build/tb_data_memory.vcd");
        $dumpvars(0, tb_data_memory);
        clk = 1'b0; MemRead = 0; MemWrite = 0; address = 0; write_data = 0;
        errors = 0;

        // 1-3. Write 25 at byte address 64, read it back, verify 25.
        do_store(32'd64, 32'd25, 1'b1);
        check_load(32'd64, 32'd25);

        // 4-5. Different values at different locations do not collide.
        do_store(32'd0,  32'h11111111, 1'b1);
        do_store(32'd4,  32'h22222222, 1'b1);
        do_store(32'd8,  32'h33333333, 1'b1);
        // 6-8. Test addresses 0, 4, 8 (word indices 0, 1, 2).
        check_load(32'd0, 32'h11111111);
        check_load(32'd4, 32'h22222222);
        check_load(32'd8, 32'h33333333);
        check_load(32'd64, 32'd25); // still intact -> no collision

        // 9. Last valid word: byte address 1020 -> word index 255.
        do_store(32'd1020, 32'hCAFEBABE, 1'b1);
        check_load(32'd1020, 32'hCAFEBABE);

        // 10. Reads when MemRead is disabled return zero.
        check_read_disabled(32'd64);

        // 11. Writes when MemWrite is disabled must not modify memory.
        do_store(32'd64, 32'hDEADDEAD, 1'b0); // MemWrite = 0
        check_load(32'd64, 32'd25);           // unchanged

        // 12. Simultaneous control: with MemWrite=0 the location is preserved,
        //     and a concurrent enabled read still returns the old value.
        @(negedge clk);
        address = 32'd4; write_data = 32'h99999999; MemWrite = 1'b0; MemRead = 1'b1;
        #1;
        if (read_data !== 32'h22222222) begin
            $display("FAIL: concurrent r/w (write disabled) addr=0x4 expected=0x22222222 got=0x%08h",
                     read_data);
            errors = errors + 1;
        end else begin
            $display("PASS: concurrent r/w (write disabled) addr=0x4 read_data=0x%08h", read_data);
        end
        MemRead = 1'b0;
        check_load(32'd4, 32'h22222222); // confirm it was never written

        // 13. Misaligned address: no write, read returns zero.
        do_store(32'd66, 32'h12345678, 1'b1); // 66 is not word-aligned
        check_load(32'd66, 32'h00000000);     // misaligned read -> 0
        check_load(32'd64, 32'd25);            // aligned neighbor intact

        // 14. Out-of-range address: no write, read returns zero.
        do_store(32'd4096, 32'h0BADF00D, 1'b1); // word index 1024 >= 256
        check_load(32'd4096, 32'h00000000);      // out-of-range read -> 0

        // 15. Data persistence after multiple clock cycles.
        repeat (5) @(posedge clk);
        check_load(32'd64,   32'd25);
        check_load(32'd1020, 32'hCAFEBABE);

        if (errors == 0)
            $display("\nDATA MEMORY TEST PASSED");
        else
            $display("\nDATA MEMORY TEST FAILED: %0d error(s)", errors);

        $finish;
    end

endmodule
