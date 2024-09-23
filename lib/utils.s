.data
debug_out: .asciz "DEBUG: %ld\n"

.text

# save caller-saved registers
.macro caller_save
	pushq	%rax
	pushq	%rcx
	pushq	%rdx
	pushq	%rdi
	pushq	%rsi
	pushq	%r8
	pushq	%r9
	pushq	%r10
	pushq	%r11
.endm

# restore caller-saved registers
.macro caller_restore
	popq	%r11
	popq	%r10
	popq	%r9
	popq	%r8
	popq	%rsi
	popq	%rdi
	popq	%rdx
	popq	%rcx
	popq	%rax
.endm

# save callee-saved registers
.macro callee_save
	pushq	%rbx
	pushq	%r12
	pushq	%r13
	pushq	%r14
	pushq	%r15
.endm


# restore callee-saved registers
.macro callee_restore
	popq	%r15
	popq	%r14
	popq	%r13
	popq	%r12
	popq	%rbx
.endm

#allign stack to size+1 (power of 2), use pop %rsp to deallign
.macro allign_stack size
	movq	%rsp, %rax
	subq	$0x8, %rax
	andq	\size, %rax
	subq	%rax, %rsp
	pushq	%rsp
	addq	%rax, (%rsp)
.endm

#allign stack to size+1 (power of 2) with offset, use pop %rsp to turn it back
.macro offset_stack size, offset
	movq	%rsp, %rax
	subq	$0x8, %rax
	subq	\offset, %rax
	andq	\size, %rax
	subq	%rax, %rsp
	pushq	%rsp
	addq	%rax, (%rsp)
.endm

# stack safe scanf
scanf_safe:
	allign_stack $0xf
	xorq	%rax, %rax
	call	scanf
	popq	%rsp # deallign stack
	ret

# stack safe printf
printf_safe:
	allign_stack $0x0f
	xorq	%rax, %rax
	call	printf
	popq	%rsp # deallign stack
	ret

.macro printf_debug val
	caller_save
	movq	$debug_out, %rdi
	movq	\val, %rsi
	call	printf_safe
	caller_restore
.endm
