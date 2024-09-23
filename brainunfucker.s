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
#	0x18 A - add A to *ptr
#	0x20 A - add A to ptr
#	0x28 - read byte into *ptr
#	0x30 - write byte from *ptr
#	0x38 - set multipier
#	0x40 - add with multiplier

.data

# --- STRINGS ---

wrong_char_str:	.asciz	"This (%c) character is not part of the brainfuck language. Maybe you put in the wrong file?\n"
few_par_str:	.asciz	"Expected closing paranthesis (]) not found until EOF. Good luck counting parantheses!\n"
many_par_str:	.asciz	"Unexpected closing paranthesis (]) found. Good luck counting parantheses!\n"
abort_str:		.asciz	"I'm aboring so I don't mess anything up.\n"
inf_loop_str:	.asciz	"\nYour program is about to enter an infinite loop!\nI'm stopping it now so I don't waste anybody's time.\n"

# --- TABLES ---

parse_table_1:
.byte	0x48	# \0
.skip	8, 0
.byte	0x8		# \t
.byte	0x8		# \n
.skip	21, 0
.byte	0x8		# space
.skip	10, 0
.byte	0x10	# +
.byte	0x18	# ,
.byte	0x20	# -
.byte	0x28	# .
.skip	13, 0
.byte	0x30	# <
.skip	1, 0
.byte	0x38	# >
.skip	28, 0
.byte	0x40	# [
.skip	1, 0
.byte	0x48	# ]
.skip	162, 0

parse_table_2:
.quad	parse_unknown
.quad	parse_whitespace
.quad	parse_plus
.quad	parse_comma
.quad	parse_minus
.quad	parse_dot
.quad	parse_less
.quad	parse_greater
.quad	parse_open
.quad	parse_close

save_table_1:
.quad	42
.quad	save_add
.quad	save_move
.quad	save_read
.quad	save_write

run_table_1:
.quad	op_exit
.quad	op_je
.quad	op_jne
.quad	op_add
.quad	op_move
.quad	op_read
.quad	op_write

.text

.include	"lib/utils.s"
.include	"lib/stk.s"

# --- PARSER ---

# stops the program and shows an error
parse_unknown:
	pushq	(%rdi, %rsi)
	stdel
	popq	%rsi
	movq	$wrong_char_str, %rdi
	call	printf_safe
	jmp		brainunfucker_abort

# ignore whitespace
parse_whitespace:
	jmp		rec_parser_loop_end

# adds an "add" instruction to the stack or modifies the previous one
parse_plus:
	cmpq	$0x8, 0x8(%rsp)
	je		parse_plus_reuse
		subq	$0x10, %rsp
		movq	$0x8, 0x8(%rsp)
		movq	$0, (%rsp)
	parse_plus_reuse:
	incq	(%rsp)
	jmp		rec_parser_loop_end
parse_minus:
	cmpq	$0x8, 0x8(%rsp)
	je		parse_minus_reuse
		subq	$0x10, %rsp
		movq	$0x8, 0x8(%rsp)
		movq	$0, (%rsp)
	parse_minus_reuse:
	decq	(%rsp)
	jmp		rec_parser_loop_end
# adds a "move" instruction to the stack or modifies the previous one
parse_less:
	cmpq	$0x10, 0x8(%rsp)
	je		parse_less_reuse
		subq	$0x10, %rsp
		movq	$0x10, 0x8(%rsp)
		movq	$0, (%rsp)
	parse_less_reuse:
	decq	(%rsp)
	jmp		rec_parser_loop_end
parse_greater:
	cmpq	$0x10, 0x8(%rsp)
	je		parse_greater_reuse
		subq	$0x10, %rsp
		movq	$0x10, 0x8(%rsp)
		movq	$0, (%rsp)
	parse_greater_reuse:
	incq	(%rsp)
	jmp		rec_parser_loop_end

# adds a "read" instruction to the stack
parse_comma:
	pushq	$0x18
	pushq	$0x0
	jmp		rec_parser_loop_end
# adds a "write" instruction to the stack
parse_dot:
	pushq	$0x20
	pushq	$0x0
	jmp		rec_parser_loop_end

# saves all instruction to the heap, recursively calls rec_parser and adds two jump instructions directly to heap for "[" and "]"
parse_open:
	call	heap_saver

	pushq	%r12
	stpushb	$0x8
	stpushq	$0
	movq	%r9, %r12
	incq	%rsi
	call	rec_parser
	stpushb	$0x10
	stpushq	%r12
	movq	%r9, -0x8(%r8, %r12)
	popq	%r12

	cmpb	$0, (%rdi, %rsi)
	je		parse_no_close
	jmp		rec_parser_loop_end

# exits the parse loop either for a "]" character or an end of string
parse_close:
	jmp		rec_parser_end

rec_parser:
	pushq	%rbp
	movq	%rbp, %
	pushq	$0	# ptr shift count / valid characters flag
	pushq	$0
	pushq	%rbx

	movq	%rsp, %rbx
	cmpb	$0, (%rdi, %rsi)
	je		rec_parser_end
	rec_parser_loop:
		movb	(%rdi, %rsi), %cl
		movb	parse_table_1(%rcx), %cl
		movq	parse_table_2(%rcx), %rax
		jmp		*%rax
		rec_parser_loop_end:
		incq	%rsi
		jne		rec_parser_loop

	rec_parser_end:
	call	heap_saver
	popq	%rbx
	addq	$0x18, %rsp
	ret

rec_parser_optimised:
	pushq	%rbp
	movq	%rbp, %
	pushq	$0	# ptr shift count / valid characters flag
	pushq	$0
	pushq	%rbx

	movq	%rsp, %rbx
	cmpb	$0, (%rdi, %rsi)
	je		rec_parser_end
	rec_parser_loop:
		movb	(%rdi, %rsi), %cl
		movb	parse_table_1(%rcx), %cl
		movq	parse_table_2(%rcx), %rax
		jmp		*%rax
		rec_parser_loop_end:
		incq	%rsi
		jne		rec_parser_loop

	rec_parser_end:
	call	heap_saver
	popq	%rbx
	addq	$0x18, %rsp
	ret

# found extra closed paranthesis
parse_no_open:
	stdel
	movq	$many_par_str, %rdi
	call	printf_safe
	jmp		brainunfucker_abort
# found EOF before closing all parantheses
parse_no_close:
	stdel
	movq	$few_par_str, %rdi
	call	printf_safe
	jmp		brainunfucker_abort

# --- HEAP SAVER ---

save_add:
	stpushb	$0x18
	subq	$0x8, %rbx
	movq	(%rbx), %rax
	stpushb	%al
	jmp		heap_saver_loop_end
save_move:
	stpushb	$0x20
	subq	$0x8, %rbx
	movq	(%rbx), %rax
	stpushq	%rax
	jmp		heap_saver_loop_end
save_read:
	stpushb	$0x28
	subq	$0x8, %rbx
	jmp		heap_saver_loop_end
save_write:
	stpushb $0x30
	subq	$0x8, %rbx
	jmp		heap_saver_loop_end
heap_saver:
	pushq	%rbx
	leaq	0x10(%rsp), %rdx
	cmpq	%rdx, %rbx
	je		heap_saver_end
	heap_saver_loop:
		subq	$0x8, %rbx
		movq	(%rbx), %rcx
		movq	save_table_1(%rcx), %rax
		jmp		*%rax
		heap_saver_loop_end:
		cmpq	%rdx, %rbx
		jne		heap_saver_loop
	heap_saver_end:
	popq	%rbx
	popq	%rax
	movq	%rbx, %rsp
	jmp		*%rax

# --- INTERPRETER ---

op_exit:
	jmp		interpreter_end
op_je:
	movb	(%rdx), %cl
	addq	$0x8, %rsi
	cmpb	$0, %cl
	jne		op_je_no_jump
		movq	-0x8(%r8, %rsi), %rsi
	op_je_no_jump:
	jmp		interpreter_loop
op_jne:
	movb	(%rdx), %cl
	addq	$0x8, %rsi
	cmpb	$0, %cl
	je		op_jne_no_jump
		movq	-0x8(%r8, %rsi), %rsi
	op_jne_no_jump:
	jmp		interpreter_loop
op_add:
	movb	(%r8, %rsi), %cl
	addb	%cl, (%rdx)
	incq	%rsi
	jmp		interpreter_loop
op_move:
	movq	(%r8, %rsi), %rax
	subq	%rax, %rdx
	addq	$0x8, %rsi

	op_move_alloc:
		cmpq	%rsp, %rdx
		jg		op_move_no_alloc
		pushq	$0
		jmp		op_move_alloc
	op_move_no_alloc:
	jmp		interpreter_loop

# TODO read from input/string
op_read:
	jmp		interpreter_loop
op_write:
	pushq	%rsi
	pushq	%rdx
	pushq	%r11

	movq	%rdx, %rsi
	movq	$1, %rax		# write
	movq	$1, %rdi		# to stdout
	movq	$1, %rdx		# 1 char
	syscall

	popq	%r11
	popq	%rdx
	popq	%rsi
	movq	$0, %rcx
	jmp		interpreter_loop

interpreter_inf_loop:
	stdel
	movq	$inf_loop_str, %rdi
	call	printf_safe
	jmp		interpreter_end

interpreter:
	pushq	%rbp
	movq	%rsp, %rbp

	pushq	$0

	movq	$0, %rsi		# instruction counter
	movq	%rsp, %rdx		# memory counter

	interpreter_loop:
		movb	(%r8, %rsi), %cl
		movq	run_table_1(%rcx), %rax
		incq	%rsi
		jmp		*%rax

	interpreter_end:
	stdel
	movq	%rbp, %rsp
	popq	%rbp
	ret


# --- UNFUCKER ---

.global brainunfucker
brainunfucker:
	pushq %rbp
	movq %rsp, %rbp

	pushq	%rdi
	stinit
	popq	%rdi
	
	# parse and save the text
	movq	$0, %rsi
	movq	$0, %rcx

	call	rec_parser
	cmpb	$0, (%rdi, %rsi)
	jne		parse_no_open
	stpushb	$0

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

	brainunfucker_abort:
	movq	$abort_str, %rdi
	call	printf_safe

	brainunfucker_end:
	movq %rbp, %rsp
	popq %rbp
	ret