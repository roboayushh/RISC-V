`timescale 1ns/1ps

// Self-checking testbench for the 32 x 32-bit register file.
module tb_register_file;

    reg         clk;
    reg  [4:0]  rs1, rs2, rd;
    reg  [31:0] write_data;
    reg         RegWrite;
    wire [31:0] read_data1, read_data2;
    integer     errors;

    register_file dut (
        .clk        (clk),
        .rs1        (rs1),
        .rs2        (rs2),
        .rd         (rd),
        .write_data (write_data),
        .RegWrite   (RegWrite),
        .read_data1 (read_data1),
        .read_data2 (read_data2)
    );

    always #5 clk = ~clk;

    // Perform one synchronous write through the write port.
    task do_write;
        input [4:0]  waddr;
        input [31:0] wdata;
        input        wen;
        begin
            @(negedge clk);
            rd         = waddr;
            write_data = wdata;
            RegWrite   = wen;
            @(posedge clk); // write commits here
            @(negedge clk);
            RegWrite   = 1'b0;
        end
    endtask

    // Check read port 1 for a given source register.
    task check_read1;
        input [4:0]  raddr;
        input [31:0] expected;
        begin
            rs1 = raddr;
            #1;
            if (read_data1 !== expected) begin
                $display("FAIL: read_data1[x%0d] expected=0x%08h got=0x%08h",
                         raddr, expected, read_data1);
                errors = errors + 1;
            end else begin
                $display("PASS: read_data1[x%0d]=0x%08h", raddr, read_data1);
            end
        end
    endtask

    // Check both read ports simultaneously (independent asynchronous reads).
    task check_read_both;
        input [4:0]  a1;
        input [4:0]  a2;
        input [31:0] e1;
        input [31:0] e2;
        begin
            rs1 = a1;
            rs2 = a2;
            #1;
            if ((read_data1 !== e1) || (read_data2 !== e2)) begin
                $display("FAIL: dual read x%0d/x%0d expected=0x%08h/0x%08h got=0x%08h/0x%08h",
                         a1, a2, e1, e2, read_data1, read_data2);
                errors = errors + 1;
            end else begin
                $display("PASS: dual read x%0d=0x%08h  x%0d=0x%08h",
                         a1, read_data1, a2, read_data2);
            end
        end
    endtask

    initial begin
        $dumpfile("build/tb_register_file.vcd");
        $dumpvars(0, tb_register_file);
        clk = 1'b0; rs1 = 0; rs2 = 0; rd = 0; write_data = 0; RegWrite = 0;
        errors = 0;

        // 1. Initialization: all general registers read as zero.
        #1;
        check_read1(5'd1, 32'h00000000);
        check_read1(5'd5, 32'h00000000);

        // 2 & 3. Write 15 into x1, then read x1.
        do_write(5'd1, 32'd15, 1'b1);
        check_read1(5'd1, 32'd15);

        // 4 & 5. Write 25 into x2, then read x1 and x2 simultaneously.
        do_write(5'd2, 32'd25, 1'b1);
        check_read_both(5'd1, 5'd2, 32'd15, 32'd25);

        // 6 & 7. Attempt to write 100 into x0; x0 must still read zero.
        do_write(5'd0, 32'd100, 1'b1);
        check_read1(5'd0, 32'h00000000);
        check_read_both(5'd0, 5'd0, 32'h00000000, 32'h00000000);

        // 8 & 11. Disable RegWrite and attempt a write to x1; value must not change.
        do_write(5'd1, 32'hDEADBEEF, 1'b0);
        check_read1(5'd1, 32'd15);

        // 9. Write different values into multiple registers.
        do_write(5'd3, 32'hAAAA_AAAA, 1'b1);
        do_write(5'd4, 32'h5555_5555, 1'b1);
        do_write(5'd31, 32'hFFFF_FFFF, 1'b1);

        // 10. Simultaneous asynchronous reads from different registers.
        check_read_both(5'd3, 5'd4, 32'hAAAA_AAAA, 32'h5555_5555);
        check_read_both(5'd31, 5'd2, 32'hFFFF_FFFF, 32'd25);

        // 12. Read behavior around a clock edge: value visible only after the edge.
        @(negedge clk);
        rd = 5'd6; write_data = 32'd77; RegWrite = 1'b1;
        rs1 = 5'd6;
        #1; // still before the rising edge -> old value (0)
        if (read_data1 !== 32'h00000000) begin
            $display("FAIL: pre-edge x6 expected=0x00000000 got=0x%08h", read_data1);
            errors = errors + 1;
        end else begin
            $display("PASS: pre-edge x6=0x%08h (write not yet committed)", read_data1);
        end
        @(posedge clk); #1; // after the edge -> new value
        RegWrite = 1'b0;
        if (read_data1 !== 32'd77) begin
            $display("FAIL: post-edge x6 expected=0x0000004d got=0x%08h", read_data1);
            errors = errors + 1;
        end else begin
            $display("PASS: post-edge x6=0x%08h (write committed)", read_data1);
        end

        if (errors == 0)
            $display("\nREGISTER FILE TEST PASSED");
        else
            $display("\nREGISTER FILE TEST FAILED: %0d error(s)", errors);

        $finish;
    end

endmodule
