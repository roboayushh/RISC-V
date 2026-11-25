`timescale 1ns/1ps
module tb_trace;
  reg clk = 0;
  reg reset = 1;
  wire [31:0] pc, instruction;
  integer i;
  rv32i_core dut (.clk(clk), .reset(reset), .pc(pc), .instruction(instruction));
  always #5 clk = ~clk;
  initial begin
    repeat (2) @(posedge clk);
    @(negedge clk); reset = 0;
    for (i = 0; i < 80; i = i + 1) begin
      #1; $display("TRACE %0d %08h %08h", i, pc, instruction);
      @(negedge clk);
    end
    $finish;
  end
endmodule
