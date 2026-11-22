# M13 arithmetic program, implemented by Samiksha for Saumya's work package.
# Expected x1=10, x2=20, x3=30, x4=10, x5=0, x6=x7=30,
# x8=0xffffffff, x9=0, x10=12, x11=10, x12=8, x13=14 and x14=6.
# The overlapping bit patterns distinguish AND, OR and XOR. Completion PC=56.
        .option norvc
        .option norelax
        .text
        .globl _start
_start:
        addi x1, x0, 10
        addi x2, x0, 20
        add  x3, x1, x2
        sub  x4, x2, x1
        and  x5, x1, x2
        or   x6, x1, x2
        xor  x7, x1, x2
        addi x8, x0, -1
        addi x9, x8, 1
        addi x10, x0, 12
        addi x11, x0, 10
        and  x12, x10, x11
        or   x13, x10, x11
        xor  x14, x10, x11
done:
        beq  x0, x0, done
