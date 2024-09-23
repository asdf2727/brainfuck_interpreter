.text

# init a stack
.macro stinit
	movq	$0x8, %rdi
	call	malloc
	movq	%rax, %r8
	movq	$0, %r9
	movq	$0x7, %r10
.endm


# delete the stack
.macro stdel
	movq	%r8, %rdi
	call	free
.endm

# save stack parameters from registers into (ptr)
.macro stsave ptr
	movq	%r8, (\ptr)			# memory block pointer
	movq	%r9, 0x8(\ptr)		# end offset
	movq	%r10, 0x10(\ptr)	# size - 1 of block
.endm


# load stack parameters from (ptr) into registers
.macro stload ptr
	movq	(\ptr), %r8
	movq	0x8(\ptr), %r9
	movq	0x10(\ptr), %r10
.endm

# check if stack is full
# stack top - the size of the object being pushed
stinc:
	pushq	%rdi
	# recast if end - begin > size (if the stack would overflow)
	cmpq	%r10, %r9
	jle		stinc_norecast

		pushq	%rax
		pushq	%rcx
		pushq	%rdx
		pushq	%rsi

		# rdi = r11 * 2 + 1
		movq	$0, %rdi
		leaq	1(%rdi, %r10, 2), %rdi
		call	strecast

		popq	%rsi
		popq	%rdx
		popq	%rcx
		popq	%rax

	stinc_norecast:
	popq	%rdi
	ret

# check if the stack is quarter full
stdec:
	push	%rdi
	# recast if (end - begin - rdi) * 4 < size (if the stack is quarter full)
	movq	%r9, %rdi
	shlq	$2, %rdi
	cmpq	%r10, %rdi
	jg		stdec_norecast

		# do not resize if under 8 bytes
		cmpq	$8, %r10
		jle		stinc_norecast

		pushq	%rax
		pushq	%rcx
		pushq	%rdx
		pushq	%rsi

		# rdi = r11 >> 1
		movq	%r10, %rdi
		shrq	$1, %rdi
		call	strecast
			
		popq	%rsi
		popq	%rdx
		popq	%rcx
		popq	%rax

	stdec_norecast:
	popq	%rdi
	ret

# recast the stack to have %rdi size 
strecast:
	pushq	%rdi
	pushq	%r8
	pushq	%r9
	pushq	%r10

	incq	%rdi
	call	malloc

	popq	%r10
	popq	%r9
	popq	%r8
	popq	%rdx

	movq	%r8, %rsi
	movq	%rax, %rdi
	movq	%r9, %rcx
	rep	movsb

	movq	%rdx, %r10
	movq	%r8, %rdi
	movq	%rax, %r8

	pushq	%r8
	pushq	%r9
	pushq	%r10
	call	free
	popq	%r10
	popq	%r9
	popq	%r8

	ret

# push SRC (not memory) into the end of the stack
.macro stpushq SRC
	addq	$0x8, %r9
	call	stinc
	movq	\SRC, -0x8(%r8, %r9)
.endm
.macro stpushl SRC
	addq	$0x4, %r9
	call	stinc
	movl	\SRC, -0x4(%r8, %r9)
.endm
.macro stpushw SRC
	addq	$0x2, %r9
	call	stinc
	movw	\SRC, -0x2(%r8, %r9)
.endm
.macro stpushb SRC
	addq	$0x1, %r9
	call	stinc
	movb	\SRC, -0x1(%r8, %r9)
.endm

# pop DST (not memory) from the end of the stack
.macro stpopq DST
	subq	$0x8, %r9
	movq	(%r8, %r9), \DST
	call	stdec
.endm
.macro stpopl DST
	subq	$0x4, %r9
	movl	(%r8, %r9), \DST
	call	stdec
.endm
.macro stpopw DST
	subq	$0x2, %r9
	movw	(%r8, %r9), \DST
	call	stdec
.endm
.macro stpopb DST
	subq	$0x1, %r9
	movb	(%r8, %r9), \DST
	call	stdec
.endm
