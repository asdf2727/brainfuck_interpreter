.text

.include "lib/inc/utils.s"
.include "lib/inc/stk.s"

# init a stack
.global	stinit
stinit:
	movq	$0x8, %rdi
	call	malloc
	movq	%rax, %r8
	movq	$0, %r9
	movq	$0x7, %r10
	ret

# delete the stack
.global	stdel
stdel:
	movq	%r8, %rdi
	call	free

# check if stack is full
.global	stinc
stinc:
	# recast if end - begin > size (if the stack would overflow)
	cmpq	%r10, %r9
	jle		stinc_norecast

		caller_save

		movq	%r10, %r9
		# rdi = r11 * 2 + 1
		movq	$0, %rdi
		leaq	1(%rdi, %r10, 2), %rdi
		call	strecast

		caller_restore

	stinc_norecast:
	ret

# check if the stack is quarter full
.global	stdec
stdec:
	push	%rdi
	# recast if (end - begin - rdi) * 4 < size (if the stack is quarter full)
	movq	%r9, %rdi
	shlq	$2, %rdi
	cmpq	%r10, %rdi
	jg		stdec_norecast

		# do not resize if under 8 bytes
		cmpq	$8, %r10
		jl		stinc_norecast

		caller_save

		# rdi = r11 >> 1
		movq	%r10, %rdi
		shrq	$1, %rdi
		call	strecast
		
		caller_restore

	stdec_norecast:
	popq	%rdi
	ret

# recast the stack to have %rdi size
.global	strecast
strecast:
	pushq	%rdi
	pushq	%r8
	pushq	%r9

	incq	%rdi
	call	malloc

	popq	%r9
	popq	%r8

	movq	%r8, %rsi
	movq	%rax, %rdi
	movq	%r9, %rcx
	rep	movsb

	movq	%r8, %rdi
	movq	%rax, %r8

	pushq	%r8
	pushq	%r9
	call	free
	popq	%r9
	popq	%r8

	popq	%r10
	ret
