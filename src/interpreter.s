.text

.include "lib/inc/stk.s"

.global runcode
runcode:
	pushq	%rbp
	pushq	%rbx
	movq	%rsp, %rbp

	# save heap stack
	subq	$0x18, %rsp
	stsave	%rsp

	# create new mapping
	movq	$9, %rax
	movq	$0, %rdi
	movq	-0x10(%rbp), %rsi
	movq	$3, %rdx
	movq	$33, %r10
	movq	$-1, %r8
	movq	$0, %r9
	syscall
	movq	%rax, %r8

	# copy code
	movq	-0x10(%rbp), %rcx
	movq	-0x18(%rbp), %rsi
	movq	%rax, %rdi
	rep movsb

	# change permissions
	movq	%rax, %rdi
	movq	$10, %rax
	movq	-0x10(%rbp), %rsi
	movq	$5, %rdx
	syscall

	# alloc stack space for memory tape
	subq	$0x8000, %rsp
	movq	$0x1000, %rcx
	movq	%rsp, %rdi
	movq	$0, %rax
	rep stosq
	
	# run code
	movq	$1, %rdi
	movq	$1, %rdx
	movq	%rsp, %rbx
	call_code:
	pushq	%r8
	call	*%r8
	popq	%r8
	
	# dealloc stack space
	addq	$0x8000, %rsp

	# delete new mapping
	movq	$11, %rax
	movq	%r8, %rdi
	movq	-0x10(%rbp), %rsi
	syscall

	# load heap stack
	stload	%rsp
	addq	$0x18, %rsp

	movq	%rbp, %rsp
	popq	%rbx
	popq	%rbp
	ret
