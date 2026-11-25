"""Deterministic audit evidence; exercises original RTL without editing it."""
from pathlib import Path
from collections import Counter
import random
import subprocess
import json

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'build/audit'
OUT.mkdir(parents=True, exist_ok=True)
MASK = 0xffffffff

def run(name, bench, sources):
    path = OUT / (name + '.v')
    path.write_text(bench)
    binary = OUT / name
    result = subprocess.run(['iverilog', '-g2012', '-s', name, '-o', str(binary),
                             *map(str, sources), str(path)], cwd=ROOT,
                            capture_output=True, text=True, timeout=60)
    log = result.stdout + result.stderr
    if result.returncode == 0:
        result = subprocess.run(['vvp', str(binary)], cwd=ROOT,
                                capture_output=True, text=True, timeout=60)
        log += result.stdout + result.stderr
    (OUT / (name + '.log')).write_text(log)
    print(log.strip())
    if result.returncode or 'AUDIT PASS' not in log:
        raise RuntimeError(name + ' failed')

run('audit_decode', '''module audit_decode;
reg [6:0] op, f7; reg [2:0] f3;
wire rw,src,mr,mw,res,br; wire [1:0] ao,im;
reg [9:0] expected; integer o,f,s,n=0;
control_unit dut(op,f3,f7,rw,src,mr,mw,res,br,ao,im);
initial begin
for(o=0;o<128;o=o+1) for(f=0;f<8;f=f+1) for(s=0;s<128;s=s+1) begin
 op=o; f3=f; f7=s; expected={6'b0,2'b11,2'b11};
 if(o==51 && ((s==0 && (f==0 || f==4 || f==6 || f==7)) || (s==32 && f==0)))
   expected={6'b100000,2'b10,2'b11};
 if(o==19 && f==0) expected={6'b110000,2'b00,2'b00};
 if(o==3 && f==2) expected={6'b111010,2'b00,2'b00};
 if(o==35 && f==2) expected={6'b010100,2'b00,2'b01};
 if(o==99 && (f==0 || f==1)) expected={6'b000001,2'b01,2'b10};
 #1; if({rw,src,mr,mw,res,br,ao,im} !== expected)
   $fatal(1,"decoder op=%h f3=%h f7=%h",op,f3,f7);
 n=n+1;
end
$display("AUDIT PASS exhaustive decode: %0d combinations",n); $finish;
end endmodule''', [ROOT/'rtl/control_unit.v'])

def enc_i(op, rd, rs, imm, f3=0):
    return ((imm & 4095)<<20)|(rs<<15)|(f3<<12)|(rd<<7)|op
def enc_s(rs, data, imm):
    return (((imm & 4095)>>5)<<25)|(data<<20)|(rs<<15)|(2<<12)|((imm & 31)<<7)|35
def enc_b(a,b,imm,f3):
    v=imm & 8191
    return ((v>>12)<<31)|(((v>>5)&63)<<25)|(b<<20)|(a<<15)|(f3<<12)|(((v>>1)&15)<<8)|(((v>>11)&1)<<7)|99
def sext(v, bits):
    return v-(1<<bits) if v & (1<<(bits-1)) else v

totals=Counter()
for seed in (20261125, 73, 4096, 0xdeadbeef):
    rng=random.Random(seed)
    regs=[0]+[rng.getrandbits(32) for _ in range(31)]
    regs[28:32]=[0,64,68,MASK-3]
    mem=[rng.getrandbits(32) for _ in range(17)]
    initial=regs+mem
    words=[]
    for j in range(8192):
        k=rng.randrange(12); rd=rng.randrange(28); a=rng.randrange(32); b=rng.randrange(32)
        imm=rng.choice([-2048,-2047,-68,-4,-3,-1,0,1,2,3,4,64,68,2047,rng.randrange(-2048,2048)])
        if k<5:
            f3=[0,0,7,6,4][k]; f7=32 if k==1 else 0
            w=(f7<<25)|(b<<20)|(a<<15)|(f3<<12)|(rd<<7)|51
        elif k==5: w=enc_i(19,rd,a,imm)
        elif k==6: w=enc_i(3,rd,rng.randrange(28,32),imm,2)
        elif k==7: w=enc_s(rng.randrange(28,32),b,imm)
        elif k in (8,9): w=enc_b(a, a if rng.randrange(2) else b, rng.choice([4,8,12,16,20,24,28,32]), k-8)
        else:
            w=rng.choice([enc_i(19,rd,a,imm,6),enc_i(3,rd,a,imm,0),
                          (1<<25)|(b<<20)|(a<<15)|(rd<<7)|51,0xffffffff,
                          enc_s(a,b,imm) ^ (2<<12),enc_b(a,b,8,4)])
        words.append(w)
    (OUT/'random_program.hex').write_text(''.join(f'{w:08x}\n' for w in words))
    pc=0; states=[]; counts=Counter()
    while pc//4<len(words):
        w=words[pc//4]; op=w&127; rd=(w>>7)&31; f3=(w>>12)&7; a=(w>>15)&31; b=(w>>20)&31; f7=w>>25
        npc=(pc+4)&MASK; value=None; name='unsupported'
        if op==51 and ((f7==0 and f3 in (0,4,6,7)) or (f7==32 and f3==0)):
            if f3==0:
                value=regs[a]-regs[b] if f7==32 else regs[a]+regs[b]; name='SUB' if f7==32 else 'ADD'
            elif f3==4: value=regs[a]^regs[b]; name='XOR'
            elif f3==6: value=regs[a]|regs[b]; name='OR'
            else: value=regs[a]&regs[b]; name='AND'
        elif op==19 and f3==0: value=regs[a]+sext(w>>20,12); name='ADDI'
        elif op==3 and f3==2:
            addr=(regs[a]+sext(w>>20,12))&MASK
            value=mem[addr//4] if addr%4==0 and addr<68 else 0; name='LW'
            counts['valid_load' if addr%4==0 and addr<68 else 'invalid_load']+=1
        elif op==35 and f3==2:
            imm=((w>>25)<<5)|((w>>7)&31); addr=(regs[a]+sext(imm,12))&MASK
            if addr%4==0 and addr<68: mem[addr//4]=regs[b]; counts['valid_store']+=1
            else: counts['invalid_store']+=1
            name='SW'
        elif op==99 and f3 in (0,1):
            imm=((w>>31)<<12)|(((w>>7)&1)<<11)|(((w>>25)&63)<<5)|(((w>>8)&15)<<1)
            taken=(regs[a]==regs[b]) if f3==0 else (regs[a]!=regs[b])
            if taken: npc=(pc+sext(imm,13))&MASK
            name='BEQ' if f3==0 else 'BNE'; counts[name+('_taken' if taken else '_fallthrough')]+=1
        if value is not None and rd: regs[rd]=value&MASK
        counts[name]+=1; pc=npc; states.extend([pc]+regs+mem)
    steps=sum(counts[n] for n in ['ADD','SUB','AND','OR','XOR','ADDI','LW','SW','BEQ','BNE','unsupported'])
    (OUT/'random_initial.hex').write_text(''.join(f'{v:08x}\n' for v in initial))
    (OUT/'random_expected.hex').write_text(''.join(f'{v:08x}\n' for v in states))
    for top,rf,dm,im in [('rv32i_core','u_regfile','u_dmem','u_imem'),('rv32i_core_full','rf','dmem','imem')]:
        name='audit_random'
        bench=f'''module {name};
reg clk=0,reset=1; wire [31:0] pc,instruction;
reg [31:0] initial_state[0:48]; reg [31:0] expected[0:{len(states)-1}];
integer i,j,off;
{top} #(.IMEM_DEPTH(8192),.DMEM_DEPTH(17),.IMEM_INIT_FILE("build/audit/random_program.hex")) dut(clk,reset,pc,instruction);
always #5 clk=~clk;
initial begin
 $readmemh("build/audit/random_initial.hex",initial_state);
 $readmemh("build/audit/random_expected.hex",expected);
 repeat(2) @(posedge clk); @(negedge clk);
 for(j=0;j<32;j=j+1) dut.{rf}.registers[j]=initial_state[j];
 for(j=0;j<17;j=j+1) dut.{dm}.memory[j]=initial_state[j+32];
 reset=0;
 for(i=0;i<{steps};i=i+1) begin
  @(posedge clk); #1; off=i*50;
  if(pc !== expected[off]) $fatal(1,"PC seed={seed} step=%0d expected=%h actual=%h",i,expected[off],pc);
  for(j=0;j<32;j=j+1) if(dut.{rf}.registers[j] !== expected[off+1+j])
   $fatal(1,"register seed={seed} step=%0d x%0d expected=%h actual=%h",i,j,expected[off+1+j],dut.{rf}.registers[j]);
  for(j=0;j<17;j=j+1) if(dut.{dm}.memory[j] !== expected[off+33+j])
   $fatal(1,"memory seed={seed} step=%0d word=%0d",i,j);
 end
 $display("AUDIT PASS random {top}: seed={seed}, {steps} steps, all registers and 17 RAM words"); $finish;
end endmodule'''
        run(name,bench, sorted((ROOT/'rtl').glob('*.v')))
        (OUT/f'random_{top}_{seed}.log').write_text((OUT/'audit_random.log').read_text())
    totals.update(counts)
    print(json.dumps({'seed':seed,'steps':steps,'coverage':counts},sort_keys=True))
(OUT/'random_coverage.json').write_text(json.dumps(totals,indent=2,sort_keys=True)+'\n')
print('TOTAL',json.dumps(totals,sort_keys=True))
