
.section .text
.global _start
_start:
	li t0,0
	lui t1,0x00004 # 20 bit
	nop
	addi t1,t1,-0x100 # 12 bit
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
	nop
	sw t0, 8(t1) 
	nop
	li t2, 0xAA
	nop
	sw t2, 4(t1) 
	nop
	lw t0, 4(t1)
	nop
	nop
	nop
	j bob

	nop
	nop
	nop
