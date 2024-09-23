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

op_exit:
	jmp		interpreter_end

# TODO read from input/string
op_read:
	jmp		interpreter_loop

op_write:
	pushq	%rsi
	pushq	%rdx
	pushq	%r11

	movq	%rdx, %rsi
	movq	$1, %rax		# write
	movq	$1, %rdi		# to stdout
	movq	$1, %rdx		# 1 char
	syscall

	popq	%r11
	popq	%rdx
	popq	%rsi
	movq	$0, %rcx
	jmp		interpreter_loop

op_mult:
	jmp		interpreter_loop

op_je:
	movb	(%rdx), %cl
	addq	$0x8, %rsi
	cmpb	$0, %cl
	jne		op_je_no_jump
		movq	-0x8(%r8, %rsi), %rsi
	op_je_no_jump:
	jmp		interpreter_loop

op_jne:
	movb	(%rdx), %cl
	addq	$0x8, %rsi
	cmpb	$0, %cl
	je		op_jne_no_jump
		movq	-0x8(%r8, %rsi), %rsi
	op_jne_no_jump:
	jmp		interpreter_loop

op_add_mult:
	jmp		interpreter_loop

op_add:
	movb	(%r8, %rsi), %cl
	addb	%cl, (%rdx)
	incq	%rsi
	jmp		interpreter_loop

op_move:
	movq	(%r8, %rsi), %rax
	subq	%rax, %rdx
	addq	$0x8, %rsi

	op_move_alloc:
		cmpq	%rsp, %rdx
		jg		op_move_no_alloc
		pushq	$0
		jmp		op_move_alloc
	op_move_no_alloc:
	jmp		interpreter_loop

.global interpreter
interpreter:
	pushq	%rbp
	movq	%rsp, %rbp

	pushq	$0

	movq	$0, %rsi		# instruction counter
	movq	%rsp, %rdx		# memory counter

	interpreter_loop:
		movb	(%r8, %rsi), %cl
		movq	interpreter_table(%rcx), %rax
		incq	%rsi
		jmp		*%rax

	interpreter_end:
	call	stdel
	movq	%rbp, %rsp
	popq	%rbp
	ret

interpreter_table:
.quad	op_exit		# 0x00
.quad	op_read		# 0x08
.quad	op_write	# 0x10
.quad	op_mult		# 0x18
.quad	op_je		# 0x20
.quad	op_jne		# 0x28
.quad	op_add_mult	# 0x30
.quad	op_add		# 0x38
.quad	op_move		# 0x40
