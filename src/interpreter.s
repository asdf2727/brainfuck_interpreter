.data

inf_loop_str:	.asciz	"\nYour program is about to enter an infinite loop!\nI'm stopping it now so I don't waste anybody's time.\n"

.text

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

	movq	$0, %rdi		# instruction counter
	leaq	-1(%rsp), %rdx	# memory counter
	pushq	$0				# create memory block 0
	jmp		interpreter_loop

	op_read:
		jmp		interpreter_loop

	op_mult:
		jmp		interpreter_loop

	op_jne:
		addq	$0x8, %rdi
		movb	(%rdx), %cl
		cmpb	$0, %cl
		je		op_jne_no_jump
			movq	-0x8(%r8, %rdi), %rdi
		op_jne_no_jump:
		jmp		interpreter_loop

	op_add:
		movb	(%r8, %rdi), %cl
		addb	%cl, (%rdx)
		incq	%rdi
		jmp		interpreter_loop

interpreter_loop:
	movb	(%r8, %rdi), %cl
	movq	interpreter_table(%rcx), %rax
	incq	%rdi
	jmp		*%rax

	op_move:
		movq	(%r8, %rdi), %rax
		subq	%rax, %rdx
		addq	$0x8, %rdi

		op_move_alloc:
			cmpq	%rsp, %rdx
			jg		op_move_no_alloc
			pushq	$0
			jmp		op_move_alloc
		op_move_no_alloc:
		jmp		interpreter_loop

	op_add_mult:
		incq	%rdi
		jmp		interpreter_loop

	op_je:
		addq	$0x8, %rdi
		movb	(%rdx), %cl
		cmpb	$0, %cl
		jne		op_je_no_jump
			movq	-0x8(%r8, %rdi), %rdi
		op_je_no_jump:
		jmp		interpreter_loop

	op_write:
		pushq	%rdi
		pushq	%rdx

		movq	%rdx, %rsi
		movq	$1, %rax		# write
		movq	$1, %rdi		# to stdout
		movq	$1, %rdx		# 1 char
		syscall

		popq	%rdx
		popq	%rdi
		movq	$0, %rcx
		jmp		interpreter_loop

interpreter_end:
	call	stdel
	movq	%rbp, %rsp
	popq	%rbp
	ret

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
