
.data
a:  .word 1, 2
    .word 3, 4
b:  .word 5, 6
    .word 7, 8
c:  .word 0, 0
    .word 0, 0

.text
.globl main


main:
    addi t0, x0, 0      # m = 0

m_loop:
    addi t1, x0, 0      # n = 0

n_loop:
    addi t2, x0, 0      # k = 0
    addi s3, x0, 0      # accumulator

k_loop:
    slli s0, t0, 2      # m * 4
    add  s0, s0, t2     # m * 4 + k
    slli s0, s0, 2      # (m * 4 + k) * 4

    lui  s1, %hi(a)
    addi s1, s1, %lo(a)
    add  s1, s1, s0
    lw   s1, 0(s1)

    slli s0, t2, 2      # k * 4
    add  s0, s0, t1     # k * 4 + n
    slli s0, s0, 2      # (k * 4 + n) * 4

    lui  s2, %hi(b)
    addi s2, s2, %lo(b)
    add  s2, s2, s0
    lw   s2, 0(s2)

    jal  ra, mult

    add  s3, s3, s4

    addi t2, t2, 1
    addi s0, x0, 2
    blt  t2, s0, k_loop # k < 2

store:
    slli s0, t0, 2      # m * 4
    add  s0, s0, t1     # m * 4 + n
    slli s0, s0, 2      # (m * 4 + n) * 4

    lui  s1, %hi(c)
    addi s1, s1, %lo(c)
    add  s1, s1, s0
    sw   s3, 0(s1)

    addi t1, t1, 1
    addi s0, x0, 2
    blt  t1, s0, n_loop # n < 2

    addi t0, t0, 1
    addi s0, x0, 2
    blt  t0, s0, m_loop # m < 2

    jal  x0, done

mult:
    add  s4, x0, x0
    add  t3, x0, s1
    add  t4, x0, s2
    addi t5, x0, 0
    addi t6, x0, 32

mult_loop:
    beq  t5, t6, mult_done
    
    andi s0, t4, 1
    beq  s0, x0, skip
    
    add  s4, s4, t3

skip:
    addi t5, t5, 1
    slli t3, t3, 1
    srli t4, t4, 1
    jal  x0, mult_loop
    
mult_done:
    jalr x0, 0(ra)

done:
    addi t0, x0, 0
    lui  t1, %hi(c)
    addi t1, t1, %lo(c)
    ebreak