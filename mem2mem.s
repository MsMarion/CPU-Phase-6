# MEM-to-MEM forwarding test (lw/sw pairs, single base pointer)
.data
v0: .word 4
v1: .word 6
v2: .word 0
v3: .word 0
v4: .word 0
v5: .word 0
v6: .word 0
v7: .word 0
v8: .word 0
v9: .word 0
v10: .word 0
v11: .word 0
v12: .word 0
v13: .word 0
v14: .word 0
v15: .word 0

.text
.globl main

main:
    # Single base pointer to contiguous data block v0..v15
    lui  s0, %hi(v0)
    addi x0, x0, 0
    addi s0, s0, %lo(v0)

    # MEM-to-MEM: each lw immediately followed by sw (forwarded store data)
    lw   t0, 0(s0)        # v0
    sw   t0, 8(s0)        # v2

    lw   t1, 4(s0)        # v1
    sw   t1, 12(s0)       # v3

    lw   t2, 8(s0)        # v2
    sw   t2, 16(s0)       # v4

    lw   t3, 12(s0)       # v3
    sw   t3, 20(s0)       # v5

    lw   t4, 16(s0)       # v4
    sw   t4, 24(s0)       # v6

    lw   t5, 20(s0)       # v5
    sw   t5, 28(s0)       # v7

    lw   t6, 24(s0)       # v6
    sw   t6, 32(s0)       # v8

    lw   s1, 28(s0)       # v7
    sw   s1, 36(s0)       # v9

    lw   s2, 32(s0)       # v8
    sw   s2, 40(s0)       # v10

    lw   s3, 36(s0)       # v9
    sw   s3, 44(s0)       # v11

    lw   s4, 40(s0)       # v10
    sw   s4, 48(s0)       # v12

    lw   s5, 44(s0)       # v11
    sw   s5, 52(s0)       # v13

    lw   s6, 48(s0)       # v12
    sw   s6, 56(s0)       # v14

    lw   s7, 52(s0)       # v13
    sw   s7, 60(s0)       # v15
    ebreak