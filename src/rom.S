
.section .text
.global _start
_start:
	li t0,0
1:
	addi t0,t0,1
	j 1b

