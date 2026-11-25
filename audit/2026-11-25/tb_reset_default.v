`timescale 1ns/1ps
module audit_reset;
  reg clk=0, reset=1;
  wire [31:0] pc, instr;
  integer j;
  rv32i_core #(.IMEM_DEPTH(1),.IMEM_INIT_FILE(""),.DMEM_DEPTH(3)) dut(clk,reset,pc,instr);
  always #5 clk=~clk;
  initial begin
    repeat(2) @(posedge clk); @(negedge clk);
    dut.u_regfile.registers[1]=32'h01234567;
    dut.u_dmem.memory[0]=32'h89abcdef;
    dut.u_imem.memory[0]=32'h00102023; // SW x1,0(x0), pending at PC zero
    repeat(3) begin @(posedge clk); #1;
      if(pc !== 0 || dut.u_dmem.memory[0] !== 32'h89abcdef)
        $fatal(1,"reset did not suppress pending store");
    end
    @(negedge clk); reset=0;
    @(posedge clk); #1;
    if(dut.u_dmem.memory[0] !== 32'h01234567) $fatal(1,"store failed");
    @(negedge clk); reset=1;
    @(posedge clk); #1;
    if(pc !== 0 || dut.u_regfile.registers[1] !== 32'h01234567 || dut.u_dmem.memory[0] !== 32'h01234567)
      $fatal(1,"warm reset state retention failed");
    @(negedge clk); dut.u_imem.memory[0]=32'h00700093; // ADDI x1,x0,7
    repeat(3) begin @(posedge clk); #1;
      if(dut.u_regfile.registers[1] !== 32'h01234567) $fatal(1,"reset did not suppress register write");
    end
    @(negedge clk); reset=0;
    @(posedge clk); #1;
    if(dut.u_regfile.registers[1] !== 7) $fatal(1,"reset release failed");
    $display("AUDIT PASS reset gating, warm-reset retention, depth-three memory integration"); $finish;
  end
endmodule

module audit_default;
  reg clk=0,reset=1;
  wire [31:0] pc,instr;
  wire halted;
  integer n, seen=0;
  rv32i_top dut(clk,reset,pc,instr,halted);
  always #5 clk=~clk;
  initial begin
    repeat(2) @(posedge clk); @(negedge clk); reset=0;
    for(n=0;n<1000;n=n+1) begin @(posedge clk); #1; if(halted) seen=seen+1; end
    $display("DEFAULT DEMO: cycles=1000 halted_samples=%0d pc=%08h x4=%0d memory_word16=%0d",seen,pc,dut.u_core.u_regfile.registers[4],dut.u_core.u_dmem.memory[16]);
    $finish;
  end
endmodule
