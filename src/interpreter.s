.data

inf_loop_str:	.asciz	"\nYour program is about to enter an infinite loop!\nI'm stopping it now so I don't waste anybody's time.\n"

.text

.include "lib/inc/utils.s"

# --- ERROR HANDLING ---

interpreter_inf_loop:
	call	stdel
	movq	$inf_loop_str, %rdi
	call	printf_safe
	movq	%rbp, %rsp
	popq	%rbp
	ret

# --- INTERPRETER ---

.global interpreter
interpreter:
	pushq	%rbp
	movq	%rsp, %rbp

	movq	$0, %rcx

	movq	$0, %rdx		# multiplier
	movq	$0, %rdi		# instruction counter
	leaq	-1(%rsp), %rsi	# memory counter
	pushq	$0				# create memory block 0
	jmp		interpreter_loop

	op_jne:
		addq	$9, %rdi
		movb	(%rsi), %cl
		cmpb	$0, %cl
		je		op_jne_no_jump
			movq	-8(%r8, %rdi), %rdi
		op_jne_no_jump:
		jmp		interpreter_loop

interpreter_loop:
	movb	(%r8, %rdi), %cl
	movq	interpreter_table(%rcx), %rax
	jmp		*%rax

	op_move:
		addq	$9, %rdi
		subq	-8(%r8, %rdi), %rsi

		cmpq	%rsp, %rsi
		jg		op_move_no_loop
		op_move_loop:
			pushq	$0
			cmpq	%rsp, %rsi
			jle		op_move_loop
		op_move_no_loop:
		jmp		interpreter_loop

	op_add:
		addq	$2, %rdi
		movb	-1(%r8, %rdi), %cl
		addb	%cl, (%rsi)
		jmp		interpreter_loop

	op_je:
		addq	$9, %rdi
		movb	(%rsi), %cl
		cmpb	$0, %cl
		jne		op_je_no_jump
			movq	-8(%r8, %rdi), %rdi
		op_je_no_jump:
		jmp		interpreter_loop

	op_add_mult:
		addq	$2, %rdi
		movb	-1(%r8, %rdi), %al
		imulq	%rdx, %rax
		addb	%al, (%rsi)
		jmp		interpreter_loop

	op_mult:
		addq	$2, %rdi

		movb	(%rsi), %cl
		addb	-1(%r8, %rdi), %cl
		jne		op_mult_not_1
			movq	$1, %rdx
			jmp		interpreter_loop
		op_mult_not_1:

		movq	$0, %rax
		movq	$0, %rdx
		movb	-1(%r8, %rdi), %dl
		movw	inv_mult_table(%rax, %rdx, 2), %cx
		movb	(%rsi), %al

		negq	%rax
		movb	%cl, %dl
		mulq	%rdx
		testb	$0x7f, %al
		jne		interpreter_inf_loop
		shrq	$7, %rax
		shrq	$8, %rcx
		mulq	%rcx
		andq	$0xff, %rax
		movq	%rax, %rdx
		printf_debug	%rdx

		jmp		interpreter_loop

	op_write:
		incq	%rdi
		pushq	%rdi
		pushq	%rsi

		movq	$1, %rax		# write
		movq	$1, %rdi		# to stdout
		movq	$1, %rdx		# 1 char
		syscall

		popq	%rsi
		popq	%rdi
		movq	$0, %rcx
		jmp		interpreter_loop

	op_read:
		incq	%rdi
		jmp		interpreter_loop

interpreter_end:
	call	stdel
	movq	%rbp, %rsp
	popq	%rbp
	ret

.data

interpreter_table:
.quad	interpreter_end		# 0x00
.quad	op_read				# 0x08
.quad	op_write			# 0x10
.quad	op_mult				# 0x18
.quad	op_je				# 0x20
.quad	op_jne				# 0x28
.quad	op_add_mult			# 0x30
.quad	op_add				# 0x38
.quad	op_move				# 0x40

# modular arithmetic black magic
# inv_mult_table(i, 2) = mod inverse of i; gcd(i, 256)
inv_mult_table:
.quad   0xab80014001800101
.quad   0xb7802b40cd800120
.quad   0xa3804d4039800110
.quad   0xef803740c5802b20
.quad   0x1b803940f1800108
.quad   0xa78023403d800d20
.quad   0x1380454029800b10
.quad   0xdf806f4035803720
.quad   0x8b807140e1800104
.quad   0x97801b40ad803920
.quad   0x83803d4019800d10
.quad   0xcf802740a5802320
.quad   0xfb802940d1800b08
.quad   0x878013401d800520
.quad   0xf380354009801710
.quad   0xbf805f4015802f20
.quad   0x6b806140c1800102
.quad   0x77800b408d803120
.quad   0x63802d40f9801910
.quad   0xaf80174085801b20
.quad   0xdb801940b1800d08
.quad   0x67800340fd803d20
.quad   0xd3802540e9800310
.quad   0x9f804f40f5802720
.quad   0x4b805140a1800304
.quad   0x57807b406d802920
.quad   0x43801d40d9800510
.quad   0x8f80074065801320
.quad   0xbb80094091800708
.quad   0x47807340dd803520
.quad   0xb3801540c9800f10
.quad   0x7f803f40d5801f20
.quad   0x2b80414081800101
.quad   0x37806b404d802120
.quad   0x23800d40b9801110
.quad   0x6f80774045800b20
.quad   0x9b80794071800908
.quad   0x27806340bd802d20
.quad   0x93800540a9801b10
.quad   0x5f802f40b5801720
.quad   0xb80314061800504
.quad   0x17805b402d801920
.quad   0x3807d4099801d10
.quad   0x4f80674025800320
.quad   0x7b80694051800308
.quad   0x78053409d802520
.quad   0x7380754089800710
.quad   0x3f801f4095800f20
.quad   0xeb80214041800302
.quad   0xf7804b400d801120
.quad   0xe3806d4079800910
.quad   0x2f80574005803b20
.quad   0x5b80594031800508
.quad   0xe78043407d801d20
.quad   0x5380654069801310
.quad   0x1f800f4075800720
.quad   0xcb80114021800704
.quad   0xd7803b40ed800920
.quad   0xc3805d4059801510
.quad   0xf804740e5803320
.quad   0x3b80494011800f08
.quad   0xc78033405d801520
.quad   0x3380554049801f10
.quad   0xff807f4055803f20