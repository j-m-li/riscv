
.section .text
.global _start
_start:
	li t0,0
	li t1,0xFF00
1:
	nop
	bgt t0, zero, bob
	nop
	addi t0,t0,1
	j 1b
	nop

bob:
	nop
	addi t0,t0,1
	sw t0, 3(t1) 
	nop
	li t2, 0xAA
	nop
	sw t2, 1(t1) 
	nop
	lw t0, 1(t1)
	nop
	j bob

	nop
	nop
	nop
