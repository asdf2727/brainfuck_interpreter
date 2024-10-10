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
	popq	%rdi

	# parse the code
	call	base_parser

	cmpb	$0, -0x1(%rdi)
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
