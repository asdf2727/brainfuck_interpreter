.text

.include "lib/inc/stk.s"

.global runcode
runcode:
	pushq	%rbp
	pushq	%rbx
	movq	%rsp, %rbp

	# save heap stack
	subq	$0x18, %rsp
	movq	%r8, -0x8(%rbp)
	movq	%r9, -0x10(%rbp)
	movq	%r10, -0x18(%rbp)

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
	movq	-0x8(%rbp), %rsi
	movq	%rax, %rdi
	rep movsb

	# change permissions
	movq	%rax, %rdi
	movq	$10, %rax
	movq	-0x10(%rbp), %rsi
	movq	$5, %rdx
	syscall

	# alloc stack space for memory tape
	subq	$0x80008, %rsp
	movq	$0x10001, %rcx
	movq	%rsp, %rdi
	movq	$0, %rax
	rep stosq
	
	# run code
	movq	$1, %rdi
	movq	$1, %rdx
	movq	$0, %rax
	movq	%rsp, %rbx
	pushq	%r8
	call_code:
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
	movq	-0x8(%rbp), %r8
	movq	-0x10(%rbp), %r9
	movq	-0x18(%rbp), %r10

	movq	%rbp, %rsp
	popq	%rbx
	popq	%rbp
	ret
