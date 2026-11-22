# M13 mixed assembly workload exercising all ten supported instructions.
# The backward BNE loop computes 3+2+1=6, stores it at byte address 64,
# reloads it, and uses arithmetic results in BEQ/BNE decisions.
# Expected x1=0, x2=x4=x6=x7=6, x3=64, x5=x8=x9=x12=0,
# x10=1 and x11=42. Memory byte addresses 68 and 72 remain zero.
# Completion PC is 84 (0x54).
        .option norvc
        .option norelax
        .text
        .globl _start
_start:
        addi x1, x0, 3
        addi x2, x0, 0
        addi x3, x0, 64
loop:
        add  x2, x2, x1
        addi x1, x1, -1
        bne  x1, x0, loop
        sw   x2, 0(x3)
        lw   x4, 0(x3)
        sub  x5, x4, x2
        and  x6, x4, x2
        or   x7, x4, x1
        xor  x8, x4, x2
        beq  x8, x0, success
        addi x9, x0, 99
        sw   x9, 4(x3)
success:
        addi x10, x0, 1
        bne  x4, x2, failed
        addi x11, x0, 42
        beq  x0, x0, done
        addi x12, x0, 99
failed:
        sw   x4, 8(x3)
done:
        beq  x0, x0, done
