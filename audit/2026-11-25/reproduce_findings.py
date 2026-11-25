"""Reproduce audit findings using disposable copies, without editing source RTL."""
from pathlib import Path
import json
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'build/audit'
SOURCES = Path(__file__).resolve().parent
OUT.mkdir(parents=True, exist_ok=True)
COPY = OUT / 'reproduction_repo'

def execute(argv, cwd=ROOT, log=None):
    result = subprocess.run(argv, cwd=cwd, capture_output=True, text=True, timeout=60)
    content = result.stdout + result.stderr
    if log:
        (OUT/log).write_text(content)
    return result.returncode, content

def replace_once(path, before, after):
    content = path.read_text()
    if content.count(before) != 1:
        raise RuntimeError(f'Expected one mutation site in {path}')
    path.write_text(content.replace(before, after))

tracked = subprocess.check_output(['git', 'ls-files'], cwd=ROOT, text=True).splitlines()
for name in tracked:
    source = ROOT/name
    if source.suffix in {'.v', '.hex', '.sh', '.S'}:
        target = COPY/name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)

result = {}
for label, sources in [
    ('rtl', sorted((ROOT/'rtl').glob('*.v'))),
    ('netlist', [ROOT/'netlist/rv32i_core_netlist.v']),
]:
    binary = OUT/(label+'_trace')
    code, log = execute(['iverilog', '-g2005', '-s', 'tb_trace', '-o', str(binary),
                         *map(str, sources), str(SOURCES/'tb_trace.v')])
    if code:
        raise RuntimeError(log)
    code, log = execute(['vvp', str(binary)], log=label+'_trace.log')
    if code:
        raise RuntimeError(log)
    result[label+'_trace'] = [line for line in log.splitlines() if line.startswith('TRACE ')]
first = next(((a, b) for a, b in zip(result['rtl_trace'], result['netlist_trace']) if a != b), None)
result = {'first_netlist_mismatch': first}
if first is None:
    raise RuntimeError('Expected netlist discrepancy no longer reproduces')

decoder = COPY/'rtl/control_unit.v'
replace_once(decoder, "if (funct3 == 3'b000) begin // ADDI",
             "if ((funct3 == 3'b000) || (funct3 == 3'b110)) begin // injected ORI")
code, log = execute(['bash', 'run_tests.sh'], COPY, 'fault_ori.log')
result['ori_mutation'] = {'exit_status': code, 'summary': log.strip().splitlines()[-1]}
if code == 0 or '9 suites passed, 2 failed' not in log:
    raise RuntimeError('ORI failure-path result changed')
shutil.copy2(ROOT/'rtl/control_unit.v', decoder)

alu = COPY/'rtl/alu.v'
replace_once(alu, "3'b001: result = a - b;", "3'b001: result = a + b;")
for script in ['run_phase2_integration.sh', 'run_memory_integration.sh']:
    code, log = execute(['bash', 'scripts/'+script], COPY, 'fault_sub_'+script+'.log')
    result[script] = {'exit_status': code,
                      'failure_lines': [s.strip() for s in log.splitlines() if 'FAIL' in s]}
    if code != 0 or 'TEST FAILED' not in log:
        raise RuntimeError('Standalone false-success result changed')
shutil.copy2(ROOT/'rtl/alu.v', alu)

wrapper = COPY/'rtl/rv32i_top.v'
replace_once(wrapper, "halted <= 1'b1;", "halted <= 1'b0;")
code, log = execute(['bash', 'scripts/run_phase2_integration.sh'], COPY, 'fault_halt.log')
result['disabled_completion'] = {'exit_status': code,
                                'observations': [s.strip() for s in log.splitlines()
                                                 if 'Timeout' in s or 'TEST PASSED' in s]}
if code != 0 or 'Timeout after 100 cycles' not in log or 'INTEGRATION TEST PASSED' not in log:
    raise RuntimeError('Timeout false-success result changed')
shutil.copy2(ROOT/'rtl/rv32i_top.v', wrapper)

(OUT/'reproduced_findings.json').write_text(json.dumps(result, indent=2)+'\n')
print(json.dumps(result, indent=2))
