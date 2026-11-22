# M13 assembly workload using Rashmi's integrated load/store path.
# Expected x1=64, x2=x3=25, x4=x5=x7=50, x6=72.
# Memory byte addresses 64 and 68 contain 25 and 50. Completion PC is 40.
        .option norvc
        .option norelax
        .text
        .globl _start
_start:
        addi x1, x0, 64
        addi x2, x0, 25
        sw   x2, 0(x1)
        lw   x3, 0(x1)
        add  x4, x2, x3
        sw   x4, 4(x1)
        lw   x5, 4(x1)
        addi x6, x1, 8
        sw   x5, -4(x6)
        lw   x7, -4(x6)
done:
        beq  x0, x0, done
