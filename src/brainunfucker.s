
.text

.include "lib/inc/utils.s"

.global brainunfucker
brainunfucker:
	pushq	%rbx
	pushq	%r12
	pushq	%r13
	pushq	%r14
	pushq	%r15
	pushq	%rbp
	movq	%rsp, %rbp

	subq	$0x18, %rsp
	pushq	%rdi
		call	stinit
		movq	%r8, -0x8(%rbp)
		movq	%r9, -0x10(%rbp)
		movq	%r10, -0x18(%rbp)
		call	stinit
	popq	%rdi

	# parse the code
	movq	$0, %r15
	call	base_parser

	cmpq	$0, %r15
	jne		brainunfucker_end	# something went wrong, abort

	# run the compiled code
	call	stdel
	movq	-0x8(%rbp), %r8
	movq	-0x10(%rbp), %r9
	movq	-0x18(%rbp), %r10
	call	runcode

	call	stdel

	brainunfucker_end:
	movq	%rbp, %rsp
	popq	%rbp
	popq	%r15
	popq	%r14
	popq	%r13
	popq	%r12
	popq	%rbx
	ret
