# M13 BNE control-flow program.
# Covers taken and false forward/backward decisions and a false self-branch.
# Expected x1=10, x2=20, x3=0, x4=30, x5=0, x6=7.
# The skipped store leaves byte address 0 at zero. Completion PC=48.
        .option norvc
        .option norelax
        .text
        .globl _start
_start:
        addi x1, x0, 10
        addi x2, x0, 20
        bne  x1, x2, different
        addi x3, x0, 99
        sw   x2, 0(x0)
different:
        addi x4, x0, 30
same:
        bne  x1, x1, same
        addi x5, x0, 3
loop:
        addi x5, x5, -1
        bne  x5, x0, loop
        addi x6, x0, 7
        bne  x1, x2, done
done:
        beq  x0, x0, done
