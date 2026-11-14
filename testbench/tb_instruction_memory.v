`timescale 1ns/1ps

module tb_instruction_memory;

    reg [31:0] address;
    wire [31:0] instruction;
    integer errors;

    // Depth matches the 4-word image exactly, so $readmemh fills the whole array
    // (no "not enough words" note). Addresses beyond index 3 exercise the
    // out-of-range path and must return NOP.
    instruction_memory #(
        .DEPTH     (4),
        .INIT_FILE ("programs/test_program.hex")
    ) dut (
        .address     (address),
        .instruction (instruction)
    );

    // Second instance with no init file: verifies the empty-init-file branch,
    // which must leave every location at the NOP fill value.
    wire [31:0] instruction_empty;
    instruction_memory #(
        .DEPTH     (16),
        .INIT_FILE ("")
    ) dut_empty (
        .address     (address),
        .instruction (instruction_empty)
    );

    task check_empty_init;
        input [31:0] test_address;
        begin
            address = test_address;
            #1;
            if (instruction_empty !== 32'h00000013) begin
                $display("FAIL: empty-init address=0x%08h expected=0x00000013 got=0x%08h",
                         test_address, instruction_empty);
                errors = errors + 1;
            end else begin
                $display("PASS: empty-init address=0x%08h instruction=0x%08h",
                         test_address, instruction_empty);
            end
        end
    endtask

    task check_instruction;
        input [31:0] test_address;
        input [31:0] expected_instruction;
        begin
            address = test_address;
            #1;
            if (instruction !== expected_instruction) begin
                $display("FAIL: address=0x%08h expected=0x%08h got=0x%08h",
                         test_address, expected_instruction, instruction);
                errors = errors + 1;
            end else begin
                $display("PASS: address=0x%08h instruction=0x%08h",
                         test_address, instruction);
            end
        end
    endtask

    initial begin
        $dumpfile("build/tb_instruction_memory.vcd");
        $dumpvars(0, tb_instruction_memory);
        errors = 0;
        address = 32'h00000000;

        // Verify the four instructions loaded from test_program.hex.
        check_instruction(32'h00000000, 32'h00500093); // ADDI x1, x0, 5
        check_instruction(32'h00000004, 32'h00A00113); // ADDI x2, x0, 10
        check_instruction(32'h00000008, 32'h002081B3); // ADD  x3, x1, x2
        check_instruction(32'h0000000C, 32'h00302023); // SW   x3, 0(x0)

        // Unused, misaligned, and out-of-range addresses return NOP.
        check_instruction(32'h00000010, 32'h00000013);
        check_instruction(32'h00000002, 32'h00000013);
        check_instruction(32'h00000040, 32'h00000013);

        // Empty/missing init file returns NOP everywhere.
        check_empty_init(32'h00000000);
        check_empty_init(32'h00000008);

        if (errors == 0)
            $display("\nINSTRUCTION MEMORY TEST PASSED");
        else
            $display("\nINSTRUCTION MEMORY TEST FAILED: %0d error(s)", errors);

        $finish;
    end

endmodule
