
.section .text
.global _start
_start:
	li t0,0
	li t1,0xFF00
1:
	nop
	bgt t0, zero, bob
	addi t0,t0,1
	j 1b

bob:
	addi t0,t0,1
	sw t0, 0(t1) 
	li t2, 0xAA
	sw t2, 1(t1) 
	lw t0, 1(t1)
	j bob

	nop
	nop
	nop
