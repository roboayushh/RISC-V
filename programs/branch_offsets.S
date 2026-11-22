# M13 branch-immediate boundary program.
# BEQ at byte 4 jumps forward by 4092 bytes to 0x1000.
# BNE at 0x1004 jumps backward by -4096 bytes, the B-immediate minimum.
# The loop runs twice. Expected x1=0, x2=0, x3=7. Completion PC=0x100c.
# Padding is canonical ADDI x0,x0,0. All targets are four-byte aligned.
        .option norvc
        .option norelax
        .text
        .globl _start
_start:
        addi x1, x0, 2
near:
        beq  x0, x0, far
        addi x2, x0, 99
        .fill (0x1000 - (. - _start)) / 4, 4, 0x00000013
far:
        addi x1, x1, -1
        bne  x1, x0, near
        addi x3, x0, 7
done:
        beq  x0, x0, done
