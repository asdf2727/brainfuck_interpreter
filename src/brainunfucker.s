# --- INTRO ---
# Hi! I'm writing this at 12:35 AM, 16/09/2024 in the first day of coding this monstruosity.
# This is supposed to be an efficient brainfuck interpreter that:
#	1. parses the entire text and optimizes everything it can
#	2. saves the optimised code as an "intermediary" language in the heap using the heap stack I made myself (see stk.s)
#	3. runs the intermediary code super fast, using a circular buffer for the memory tape (see cbuf.s)
# Since for now I'm still working on the parser I don't know exactly how it'll end up but here are some optimiztions that i thought of:
#	[x] run all consecutive +/- and >/< operations in a single operation
#		this might actually be the biggest optimization since a normal program is full of long strings of the same symbol
#	[ ] run loops that:
#			a. don't have other loops inside them
#			b. start and end at the same ptr position
#			c. don't have I/O operations
#		in a single run, multiplying the normal +/- operation by the number of repetitions
#		e.g. [<++++>-] would be converted to *(ptr-1) += 4 * *(ptr); *(ptr) = 0
#		this should help with a lot of tedious operations of this kind that always pop up in brainfuck programs
#	[ ] make the "intermediary" language actually just hex instructions and run it natively
#		this would make it blazing fast, but it would also burn my brain trying to understand how to write and run code in the heap
# These are all the ideas I had until now, but we'll see how many end up in the final version

# Intermediary language instructions:
#	0x00 - exit the program
#	0x08 A - jump to A if *ptr is 0 (used for open braket)
#	0x10 A - jump to A if *ptr is NOT 0 (used for closed braket)
#	0x18 - set multipier
#	0x20 A - add A to ptr
#	0x28 A - add A to *ptr
#	0x30 A - add A to *ptr with multiplier
#	0x38 - read byte into *ptr
#	0x40 - write byte from *ptr

.text

.include "lib/inc/stk.s"

.global brainunfucker
brainunfucker:
	pushq %rbp
	movq %rsp, %rbp

	pushq	%rdi
	call	stinit
	popq	%rdi

	# parse the code
	call	base_parser

	# run the intermedeary
	call	interpreter

	# print an extra \n
	pushq	$10			# \n
	movq	%rsp, %rsi
	movq	$1, %rax	# write
	movq	$1, %rdi	# to stdout
	movq	$1, %rdx	# 1 char
	syscall
	jmp		brainunfucker_end

	brainunfucker_end:
	movq %rbp, %rsp
	popq %rbp
	ret
