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
