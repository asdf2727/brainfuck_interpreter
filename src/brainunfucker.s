
.text

.include "lib/inc/utils.s"

.global brainunfucker
brainunfucker:
	pushq	%rbp
	pushq	%rbx
	pushq	%r12
	pushq	%r13
	pushq	%r14
	pushq	%r15
	movq	%rsp, %rbp

	pushq	%rdi
	call	stinit
	movq	$0x10000, %rdi
	call	stresize
	movq	$0, %r9
	popq	%rdi

	# parse the code
	movq	$0, %rbx
	call	base_parser

	cmpq	$0, %rbx
	jne		brainunfucker_end	# something went wrong, abort

	# run the compiled code
	call	runcode

	call	stdel

	brainunfucker_end:
	movq %rbp, %rsp
	popq	%r15
	popq	%r14
	popq	%r13
	popq	%r12
	popq	%rbx
	popq %rbp
	ret
