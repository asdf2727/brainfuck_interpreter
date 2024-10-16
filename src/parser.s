# %rdi - current char pointer
# stack - instruction buffer
# st (in the heap) - intermideary code result

.data

few_par_str:	.asciz	"Expected closing paranthesis (]) not found until EOF. Good luck counting parantheses!\n"
many_par_str:	.asciz	"Unexpected closing paranthesis (]) found. Good luck counting parantheses!\n"

.text

.include "lib/inc/stk.s"
.include "lib/inc/utils.s"

# --- BASE PARSER ---

# Found extra closed paranthesis
no_open_par:
	call	stdel
	movq	$many_par_str, %rdi
	call	printf_safe
	movq	$1, %rbx
	movq	%r15, %rsp
	popq	%rbp
	ret

# Base parser - parses the initial string
.global base_parser
base_parser:
	# Prolouge
	pushq	%rbp
	movq	%rsp, %rbp
	movq	%rsp, %r15				# panic stack position revert

	movq	$0, %rcx				# rcx should always be 0 except for low byte

	pushq	$0						# begin loop position
	pushq	$0						# tape pointer offset
	pushq	$base_parser_loop_end	# ret address for parser_loop
	pushq	$1						# optimise loop to mult (if 0)

	# First add
	pushq	$0
	pushq	$0

	# Parse string
	jmp		parser_loop
	base_parser_loop_end:

	# Panic if not expected ] found
	cmpb	$93, -0x1(%rdi)
	je		no_open_par
	
	# Return when done
	call	save_ret

	# Epilouge
	movq	%rbp, %rsp
	popq	%rbp
	ret

# --- RECURSIVE PARSER ---

# found EOF before closing all parantheses
no_closed_par:
	call	stdel
	movq	$few_par_str, %rdi
	call	printf_safe
	movq	$2, %rbx
	movq	%r15, %rsp
	popq	%rbp
	ret

# Parses a pair of parantheses and the code inside it
rec_parser:
	# Prolouge
	pushq	%rbp
	movq	%rsp, %rbp

	# Initial opening paranthesis for this sequence
	call	save_open

	pushq	%r9						# begin loop position
	pushq	$0						# tape pointer offset
	pushq	$rec_parser_loop_end	# ret address for parser_loop
	pushq	$0						# optimise loop to mult (if 0)

	# First add
	pushq	$0
	pushq	$0

	# Parse substring
	jmp		parser_loop
	rec_parser_loop_end:

	# Panic if expected ] not found
	cmpb	$93, -0x1(%rdi)
	jne		no_closed_par

	# Decide whether to use optimisation or not
	movq	-0x10(%rbp), %rax
	orq		-0x20(%rbp), %rax
	cmpq	$0, %rax
	jne		rec_parser_no_optimise

rec_parser_optimise:
	# Optimisation used
	call	save_mult				# calculate how many times the loop repeats (N) using modular arithmetic
	call	save_mult_add			# multiply each addition by N and add to correct byte
	
	# fix [ jump offset
	movq	-0x8(%rbp), %rax
	movl	%r9d, -0x4(%r8, %rax)
	subl	%eax, -0x4(%r8, %rax)

	# Epilouge
	movq	%rbp, %rsp
	popq	%rbp
	ret

rec_parser_no_optimise:
	# Optimisation not used
	call	save_add				# do each addition to the correct byte
	call	save_move				# move TP to prepare for what's next
	call	save_close				# close the paranthesis with a jne
	
	# fix [ jump offset
	movq	-0x8(%rbp), %rax
	movl	%r9d, -0x4(%r8, %rax)
	subl	%eax, -0x4(%r8, %rax)
	# fix ] jump offset
	movl	%eax, -0x4(%r8, %r9)
	subl	%r9d, -0x4(%r8, %r9)

	# Epilouge
	movq	%rbp, %rsp
	popq	%rbp
	ret

# --- PARSER LOOP ---

.data

ascii_table:
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

jump_table:
.quad	parser_loop
.quad	parser_loop
.quad	parse_plus
.quad	parse_comma
.quad	parse_minus
.quad	parse_dot
.quad	parse_less
.quad	parse_greater
.quad	parse_open
.quad	parser_loop_end

.text

# stops the program and shows an error - not used for export version usually
parse_unknown:
	decq	%rdi
	movq	$1, %rdx
	parse_unknown_loop:
		movb	(%rdi, %rdx), %cl
		incq	%rdx
		cmpb	$9, %cl
		je		parse_unknown_loop
		cmpb	$32, %cl
		je		parse_unknown_loop
		movb	ascii_table(%rcx), %cl
		cmpb	$0, %cl
		je		parse_unknown_loop
	decq	%rdx

	pushq	%rsi
	pushq	%rdi
	addq	%rdx, (%rsp)
		movq	$1, %rax
		movq	%rdi, %rsi
		movq	$2, %rdi
		syscall
		movq	$1, %rax
		movq	$2, %rdi
		movq	$1, %rdx
		pushq	$10
		movq	%rsp, %rsi
		syscall
		addq	$0x8, %rsp
	popq	%rdi
	popq	%rsi

	movq	$0, %rcx

	jmp		parser_loop

# parser loop - parses everything until ']' or '\0'
parser_loop:
	movb	(%rdi), %cl
	movb	ascii_table(%rcx), %cl		# first parse table gives offset into second parse table
	movq	jump_table(%rcx), %rax		# second parse table gives pointer to correct switch case
	incq	%rdi
	jmp		*%rax
	
	parse_less:
		# Parse '<'
		decq	-0x10(%rbp)				# Decrease TP
		jmp		parser_loop				# return
	parse_greater:
		# Parse '>'
		incq	-0x10(%rbp)				# Increase TP
		jmp		parser_loop				# return

	parse_plus:
		# Parse '+'
		movq	-0x10(%rbp), %rax
		cmpq	0x8(%rsp), %rax			# check if last addition used same TP
		je		parse_plus_reuse
			pushq	%rax				# if not, create new addition
			pushq	$0
		parse_plus_reuse:
		incq	(%rsp)					# increase count for this addition
		jmp		parser_loop				# return
	parse_minus:
		# Parse '-'
		movq	-0x10(%rbp), %rax
		cmpq	0x8(%rsp), %rax			# check if last addition used same TP
		je		parse_minus_reuse
			pushq	%rax				# if not, create new addition
			pushq	$0
		parse_minus_reuse:
		decq	(%rsp)					# decrease count for this addition
		jmp		parser_loop				# return
	
	parse_open:
		# Parse '['
		movq	$1, -0x20(%rbp)			# Disable optimisation for this loop - optimised loop cannot have loops inside it
		call	save_add				# Save all additions parsed up to now
		call	save_move				# Move TP to prepare for what's inside loop
		call	rec_parser				# Recursively parse the inside loop
		jmp		parser_loop				# return
	
	parse_dot:
		# Parse '.'
		movq	$1, -0x20(%rbp)			# Disable optimisation for this loop - optimised loop cannot have IO inside it
		call	save_add				# Save all additions parsed up to now
		call	save_write				# Write a character to output
		jmp		parser_loop				# return
	parse_comma:
		# Parse ','
		movq	$1, -0x20(%rbp)			# Disable optimisation for this loop - optimised loop cannot have IO inside it
		call	save_add				# Save all additions parsed up to now
		call	save_read				# Read a character from input
		jmp		parser_loop				# return

	parser_loop_end:
	jmp		*-0x18(%rbp)				# Exit parse loop to the 3rd value in the stack
