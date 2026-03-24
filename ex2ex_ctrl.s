# EX-to-EX forwarding control test (branch and jump dependencies)
.data
x: .word 7
y: .word 3
z: .word 0
z1: .word 0
z2: .word 0
z3: .word 0
z4: .word 0
z5: .word 0
z6: .word 0
z7: .word 0
z8: .word 0
z9: .word 0
z10: .word 0
z11: .word 0
z12: .word 0

.text
.globl main

main:
	# Load x and y
	lui  a6, %hi(x)
	addi a6, a6, %lo(x)
	lw   t0, 0(a6)
	lui  a7, %hi(y)
	addi a7, a7, %lo(y)
	lw   t1, 0(a7)

	# Base pointer to z (z..z12 are contiguous words)
	lui  s0, %hi(z)
	addi s0, s0, %lo(z)

	# R-type
	add t2, t0, t1
	sub t3, t2, t1

	# I-type
	addi t4, t0, 5
	slli t5, t4, 2

	# S-type: add followed by sw using produced base register (EX-to-EX)
	addi t6, a6, 8
	sw   t2, 8(t6)

	# B-type: beq reads a just-produced register (EX-to-EX)
	addi a5, t2, 0
	beq  a5, t2, branch1
	sub  a5, t2, t1
branch1:
	add  a5, t2, t1

	# R-type
	and s2, t2, t1
	or  s3, s2, t1

	# I-type
	xori s4, t2, 12
	slti s5, s4, 20

	# J-type: add reads link register from jal (EX-to-EX)
	jal  s6, jump_target
jump_pad:
	addi s1, zero, 0
jump_target:
	add  s1, s6, t1

	# U-type
	lui s8, 0x12345
	add s9, s8, t1

	# U-type
	auipc s10, 0x100
	sub s11, s10, t1

	# R-type
	sll a0, t2, t1
	srl a1, a0, t1

	# I-type
	ori a2, t2, 0xFF
	addi a3, a2, 7

	# S-type: xor followed by sw using produced base register (EX-to-EX)
	addi a4, a7, 16
	sw   t2, -16(a4)

	# Store all outputs at the end
	sw   t3, 0(s0)     # z
	sw   t5, 4(s0)     # z1
	sw   t6, 12(s0)    # z3
	sw   a5, 16(s0)    # z4 (branch test result)
	sw   s3, 20(s0)    # z5
	sw   s5, 24(s0)    # z6
	sw   s1, 28(s0)    # z7 (jump test result)
	sw   s9, 32(s0)    # z8
	sw   s11, 36(s0)   # z9
	sw   a1, 40(s0)    # z10
	sw   a3, 44(s0)    # z11
	sw   a4, 48(s0)
	ebreak