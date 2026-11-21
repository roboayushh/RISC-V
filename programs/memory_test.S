# =============================================================================
# memory_test.S — Rashmi, Phase 2 (M11): LW/SW memory verification program
#
# This is the canonical load/store example from the Phase 2 work distribution.
# It is the human-readable source for programs/memory_test.hex.
#
# Memory model (from rtl/data_memory.v): byte-addressed, word index = addr >> 2.
# So byte address 64 maps to data-memory word index 16.
#
# Expected final state:
#   x1 = 64                 (base address)
#   x2 = 25                 (value to store)
#   mem[byte 64] = 25       (== data_memory word 16)
#   x3 = 25                 (loaded back from memory)
#   x4 = 50                 (x2 + x3)
#
# Assembler note: no RISC-V assembler is installed in this environment
# (riscv64-unknown-elf-as / llvm-mc absent), so programs/memory_test.hex was
# produced by verified hand-encoding and validated end-to-end in simulation by
# testbench/tb_memory_integration.v (the identical program "mem_basic").
# =============================================================================

        .text
        .globl _start
_start:
        addi  x1, x0, 64        # x1 = 64  -> base byte address (word 16)
        addi  x2, x0, 25        # x2 = 25  -> value to store
        sw    x2, 0(x1)         # mem[64] = 25   (data_memory word 16)
        lw    x3, 0(x1)         # x3 = mem[64] = 25
        add   x4, x2, x3        # x4 = 25 + 25 = 50

halt:   beq   x0, x0, halt      # branch-to-self: single-cycle core "halts" here
