.data

.equ	WRITE_BUFFER_SIZE, 0x10000

copy_funcs:

read_char:
	xorl	%eax, %eax
	movb	$1, %al
	movl	%eax, %edi
	syscall

	pushq	%rsi
		xorl	%eax, %eax
		xorl	%edi, %edi
		xorl	%edx, %edx
		movb	$1, %dl
		leaq	(%rbx), %rsi
		syscall
	popq	%rsi

	xorl	%edx, %edx
	ret

write_char:
	#cmpb	$0x1b, (%rbx)
	#je		write_char_flush
	cmpl	$WRITE_BUFFER_SIZE, %edx
	jl		write_char_no_flush
	write_char_flush:
		xorl	%eax, %eax
		movb	$1, %al
		movl	%eax, %edi
		syscall
		xorl	%edx, %edx
	write_char_no_flush:
	movb	(%rbx), %al
	movb	%al, (%rsi, %rdx)
	incl	%edx
	ret

copy_funcs_end:

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
	addq	$(copy_funcs_end - copy_funcs), %rsi
	movq	$3, %rdx
	movq	$33, %r10
	movq	$-1, %r8
	movq	$0, %r9
	syscall
	movq	%rax, %r8

	# copy functions
	movq	$(copy_funcs_end - copy_funcs), %rcx
	movq	$copy_funcs, %rsi
	movq	%rax, %rdi
	rep movsb

	# copy code
	movq	-0x10(%rbp), %rcx
	movq	-0x8(%rbp), %rsi
	rep movsb

	# change permissions
	movq	%rax, %rdi
	movq	$10, %rax
	movq	-0x10(%rbp), %rsi
	movq	$5, %rdx
	syscall

	# alloc stack space for memory tape
	subq	$0x80000, %rsp
	movq	$0x10000, %rcx
	movq	%rsp, %rdi
	movq	$0, %rax
	rep stosq
	
	# run code
	movq	%rsp, %rbx
	subq	$WRITE_BUFFER_SIZE, %rsp
	movq	%rsp, %rsi
	movq	$0, %rdx
	leaq	write_char - copy_funcs(%r8), %r9
	leaq	write_char_flush - copy_funcs(%r8), %r10
	leaq	copy_funcs_end - copy_funcs(%r8), %r11
	pushq	%r8
	call_code:
	call	*%r11
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
