.text

.include "lib/inc/stk.s"

# init a stack
.global	stinit
stinit:
	movq	$0x10, %rdi
	call	malloc
	movq	%rax, %r8
	movq	$0, %r9
	movq	$0xf, %r10
	ret

# delete the stack
.global	stdel
stdel:
	movq	%r8, %rdi
	call	free
	ret

# check if stack is full
.global	stinc
stinc:
	# recast if end - begin > size (if the stack would overflow)
	cmpq	%r10, %r9
	jle		stinc_norecast

		pushq	%rdi
		pushq	%rsi

		leaq	1(%r10), %rdi
		movq	%rdi, %rsi
		shlq	$1, %rdi
		shrq	$3, %rsi
		call	strecast

		popq	%rsi
		popq	%rdi

	stinc_norecast:
	ret

# check if the stack is quarter full
.global	stdec
stdec:
	# recast if end - begin < size / 4 (if the stack is quarter full)
	push	%rdi

	leaq	1(%r10), %rdi
	shrq	$2, %rdi
	cmpq	%rdi, %r9
	jg		stdec_norecast

	# do not resize if 16 bytes or under
	cmpq	$0xf, %r10
	jle		stdec_norecast

		pushq	%rsi

		movq	%rdi, %rsi
		shlq	$1, %rdi
		shrq	$3, %rsi
		call	strecast
		
		popq	%rsi

	stdec_norecast:
	popq	%rdi
	ret

# recast the stack to have a new size
# %rdi - the new size of the stack in bytes
# %rsi - the number of quads to copy from the old stack
.global	strecast
strecast:
	pushq	%rax
	pushq	%rcx
	pushq	%rdx
	pushq	%r11

	pushq	%rdi
	pushq	%r9

		pushq	%r8
		pushq	%rsi
			call	malloc
		popq	%rcx
		popq	%rsi

		movq	%rax, %rdi
		movq	%rsi, %rdx
		rep	movsq
		movq	%rdx, %rdi

		pushq	%rax
			call	free
		popq	%r8

	popq	%r9
	popq	%r10
	decq	%r10
	
	popq	%r11
	popq	%rdx
	popq	%rcx
	popq	%rax
	ret
