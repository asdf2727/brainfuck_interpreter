
.text

.include "lib/inc/utils.s"

.global brainunfucker
brainunfucker:
	# Prolouge
	pushq	%rbp
	pushq	%rbx
	pushq	%r12
	pushq	%r13
	pushq	%r14
	pushq	%r15
	movq	%rsp, %rbp

	# Init heap array
	pushq	%rdi
	call	stinit
	popq	%rdi

	# parse the code
	movq	$0, %rbx
	call	base_parser

	# abort if error code is not 0
	cmpq	$0, %rbx
	jne		brainunfucker_end

	# run the compiled code
	call	runcode

	# free the heap
	call	stdel

	brainunfucker_end:
	# Epilouge
	movq	%rbp, %rsp
	popq	%r15
	popq	%r14
	popq	%r13
	popq	%r12
	popq	%rbx
	popq %rbp
	ret
