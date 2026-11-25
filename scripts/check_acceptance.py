"""Check ROM synthesis parity, default demo completion, and runner failure paths."""
from pathlib import Path
import os
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/acceptance'
OUT.mkdir(parents=True, exist_ok=True)


def run(args, cwd=ROOT, expected=0, env=None):
    result = subprocess.run(args, cwd=cwd, capture_output=True, text=True, timeout=120, env=env)
    if (expected == 0 and result.returncode != 0) or (expected != 0 and result.returncode == 0):
        raise RuntimeError(f'{args}: unexpected exit {result.returncode}\n{result.stdout}{result.stderr}')
    return result.stdout + result.stderr


for empty in (False, True):
    label = 'empty' if empty else 'partial'
    wrapper = OUT / (label + '.v')
    image = '' if empty else 'programs/test_program.hex'
    wrapper.write_text('module rom_contract(input [31:0] address, output [31:0] instruction);\n'
                       'instruction_memory #(.DEPTH(17),.INIT_WORDS(4),'
                       f'.INIT_FILE("{image}")) dut(address,instruction);\nendmodule\n')
    netlist = OUT / (label + '_netlist.v')
    run(['yosys', '-Q', '-q', '-p', f'read_verilog -DSYNTHESIS rtl/instruction_memory.v {wrapper}; '
         f'synth -top rom_contract; check -assert; write_verilog -noattr {netlist}'])
    bench = OUT / 'tb_rom.v'
    words = ['00500093', '00a00113', '002081b3', '00302023']
    cases = '' if empty else '\n'.join(f"{i*4}: expected=32'h{w};" for i, w in enumerate(words))
    bench.write_text('''module tb_rom;
reg [31:0] address, expected; wire [31:0] instruction; integer i;
rom_contract dut(address,instruction);
initial begin
 for(i=0;i<80;i=i+1) begin
  address=i; expected=32'h00000013;
  case(i)
''' + cases + '''
  default: begin end
  endcase
  #1; if(instruction !== expected) $fatal(1,"ROM address=%h expected=%h got=%h",address,expected,instruction);
 end
 address=32'hfffffffc; #1;
 if(instruction !== 32'h13) $fatal(1,"high address aliased ROM");
 $display("ROM CONTRACT PASSED"); $finish;
end endmodule
''')
    for kind, sources in [('rtl', ['rtl/instruction_memory.v', str(wrapper)]), ('netlist', [str(netlist)])]:
        binary = OUT / (label + '_' + kind)
        run(['iverilog', '-g2005', '-s', 'tb_rom', '-o', str(binary), *sources, str(bench)])
        assert 'ROM CONTRACT PASSED' in run(['vvp', str(binary)])
    print('PASS ROM synthesis parity:', label)

bench = OUT / 'tb_default.v'
bench.write_text('''`timescale 1ns/1ps
module tb_default;
reg clk=0,reset=1; wire [31:0] pc,instruction; wire halted; integer cycles=0;
rv32i_top dut(clk,reset,pc,instruction,halted);
always #5 clk=~clk;
initial begin
 repeat(2) @(posedge clk); @(negedge clk); reset=0;
 while(!halted && cycles<100) begin @(posedge clk); #1; cycles=cycles+1; end
 if(!halted || pc !== 32'h54 || dut.u_core.u_regfile.registers[4] !== 6 ||
    dut.u_core.u_dmem.memory[16] !== 6) $fatal(1,"default demo failed");
 $display("DEFAULT DEMO PASSED"); $finish;
end endmodule
''')
run(['iverilog', '-g2005', '-s', 'tb_default', '-o', str(OUT/'default'),
     *map(str, sorted((ROOT/'rtl').glob('*.v'))), str(bench)])
assert 'DEFAULT DEMO PASSED' in run(['vvp', str(OUT/'default')])
print('PASS default mixed demo result and completion')

# Compare committed core netlist and RTL outputs through and beyond completion.
trace = ROOT / 'audit/2026-11-25/tb_trace.v'
traces = []
for name, sources in [('rtl', sorted((ROOT/'rtl').glob('*.v'))),
                      ('netlist', [ROOT/'netlist/rv32i_core_netlist.v'])]:
    binary = OUT / ('trace_' + name)
    run(['iverilog', '-g2005', '-s', 'tb_trace', '-o', str(binary), *map(str, sources), str(trace)])
    traces.append([s for s in run(['vvp', str(binary)]).splitlines() if s.startswith('TRACE ')])
assert len(traces[0]) == 80 and traces[0] == traces[1], 'core netlist differs from RTL'
print('PASS core RTL/netlist trace: 80 samples')

copy = OUT / 'mutants'
for directory in ['rtl', 'testbench', 'scripts', 'programs']:
    shutil.copytree(ROOT/directory, copy/directory, dirs_exist_ok=True)
alu = copy/'rtl/alu.v'
original = alu.read_text()
assert "3'b001: result = a - b;" in original
alu.write_text(original.replace("3'b001: result = a - b;", "3'b001: result = a + b;"))
for script in ['run_phase2_integration.sh', 'run_memory_integration.sh']:
    log = run(['bash', 'scripts/'+script], cwd=copy, expected=1)
    assert 'FAIL' in log, log
    print('PASS rejects wrong SUB:', script)
alu.write_text(original)
wrapper = copy/'rtl/rv32i_top.v'
s = wrapper.read_text()
assert "halted <= 1'b1;" in s
wrapper.write_text(s.replace("halted <= 1'b1;", "halted <= 1'b0;"))
log = run(['bash', 'scripts/run_phase2_integration.sh'], cwd=copy, expected=1)
assert 'Timeout' in log and 'INTEGRATION TEST PASSED' not in log, log
print('PASS rejects completion timeout')
# A simulator that exits zero without completion output must also be rejected.
wrapper.write_text(s)
mock_dir = OUT / 'mock_tools'
mock_dir.mkdir(exist_ok=True)
mock = mock_dir / 'vvp'
mock.write_text('#!/bin/sh\nexit 0\n')
mock.chmod(0o755)
env = dict(os.environ, PATH=str(mock_dir)+os.pathsep+os.environ['PATH'])
for script in ['run_phase2_integration.sh', 'run_memory_integration.sh']:
    run(['bash', 'scripts/'+script], cwd=copy, expected=1, env=env)
    print('PASS rejects missing completion output:', script)
print('ACCEPTANCE CHECKS PASSED')
