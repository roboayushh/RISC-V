# M13 BEQ control-flow program.
# Covers a forward skip, false self-branch, false backward branch,
# taken backward loop and a taken branch whose target is PC+4.
# Expected x1=x2=10, x3=0, x4=20, x5=0, x6=7.
# Both skipped stores leave byte addresses 0 and 4 at zero. Completion PC=60.
        .option norvc
        .option norelax
        .text
        .globl _start
_start:
        addi x1, x0, 10
        addi x2, x0, 10
        beq  x1, x2, equal
        addi x3, x0, 99
        sw   x1, 0(x0)
equal:
        addi x4, x0, 20
different:
        beq  x1, x4, different
        beq  x1, x4, equal
        addi x5, x0, 3
loop:
        addi x5, x5, -1
        beq  x5, x0, finished
        beq  x0, x0, loop
        sw   x1, 4(x0)
finished:
        addi x6, x0, 7
        beq  x1, x2, done
done:
        beq  x0, x0, done
