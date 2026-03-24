# MEM-to-EX forwarding test (focused)
.data
a: .word 10
b: .word 5
c: .word 0
d: .word 0
e: .word 0
f: .word 0
g: .word 0
h: .word 0
i: .word 0
j: .word 0
k: .word 0
l: .word 0
m: .word 0
n: .word 0
o: .word 0
p: .word 0

.text
.globl main

main:
    # Base pointer to contiguous data block a..p
    lui  s0, %hi(a)
    addi x0, x0, 0
    addi s0, s0, %lo(a)

    # MEM-to-EX: lw followed immediately by arithmetic
    lw   t0, 0(s0)       # a
    addi t1, t0, 0
    addi x0, x0, 0
    sw   t1, 8(s0)       # c

    lw   t2, 4(s0)       # b
    sub  t3, t2, t0
    addi x0, x0, 0
    sw   t3, 12(s0)      # d

    lw   t4, 8(s0)       # c
    and  t5, t4, t3
    addi x0, x0, 0
    sw   t5, 16(s0)      # e

    lw   t6, 12(s0)      # d
    or   s1, t6, t5
    addi x0, x0, 0
    sw   s1, 20(s0)      # f

    lw   s2, 16(s0)      # e
    xor  s3, s2, s1
    addi x0, x0, 0
    sw   s3, 24(s0)      # g

    lw   s4, 20(s0)      # f
    slt  s5, s4, s3
    addi x0, x0, 0
    sw   s5, 28(s0)      # h

    lw   s6, 24(s0)      # g
    sll  s7, s6, s5
    addi x0, x0, 0
    sw   s7, 32(s0)      # i

    # MEM-to-EX: lw followed by immediate-form use (no EX-to-EX chain)
    lw   a0, 28(s0)      # h
    addi x0, x0, 0
    addi a2, a0, 1
    sw   a2, 36(s0)      # j

    lw   a3, 32(s0)      # i
    addi x0, x0, 0
    addi a5, a3, -2
    sw   a5, 40(s0)      # k

    lw   a6, 36(s0)      # j
    addi x0, x0, 0
    addi a6, a6, 3
    sw   a6, 44(s0)      # l

    lw   s8, 40(s0)      # k
    addi x0, x0, 0
    andi s10, s8, 4
    sw   s10, 48(s0)     # m

    lw   s11, 44(s0)     # l
    addi x0, x0, 0
    ori  a1, s11, 5
    sw   a1, 52(s0)      # n

    # MEM-to-EX: lw followed by branch use
    lw   a2, 52(s0)      # n
    bne  a2, x0, branch_target
    addi a3, x0, 0

branch_target:
    addi a3, x0, 42
    addi x0, x0, 0
    sw   a3, 56(s0)      # o
    ebreak