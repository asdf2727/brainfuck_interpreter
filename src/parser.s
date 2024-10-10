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

# found extra closed paranthesis
no_open_par:
	call	stdel
	movq	$many_par_str, %rdi
	call	printf_safe
	movq	%r15, %rsp
	popq	%rbp
	ret

.global base_parser
base_parser:
	movq	%rbp, %r15	# panic stack position revert
	pushq	%rbp
	movq	%rsp, %rbp

	movq	$0, %rcx	# rcx should be 0 except for low byte

	pushq	$0						# begin loop position
	pushq	$0						# tape pointer offset
	pushq	$base_parser_loop_end	# ret address for parser_loop
	pushq	$1						# optimise loop to mult (if 0)

	# first add
	pushq	$0
	pushq	$0

	jmp		parser_loop
	base_parser_loop_end:

	# panic if not expected ] found
	cmpb	$93, -0x1(%rdi)
	je		no_open_par
	
	call	save_ret

	movq	%rbp, %rsp
	popq	%rbp
	ret

# --- RECURSIVE PARSER ---

# found EOF before closing all parantheses
no_closed_par:
	call	stdel
	movq	$few_par_str, %rdi
	call	printf_safe
	movq	%r15, %rsp
	popq	%rbp
	ret

rec_parser:
	pushq	%rbp
	movq	%rsp, %rbp

	call	save_open

	pushq	%r9						# begin loop position
	pushq	$0						# tape pointer offset
	pushq	$rec_parser_loop_end	# ret address for parser_loop
	pushq	$0						# optimise loop to mult (if 0)

	# first add
	pushq	$0
	pushq	$0

	jmp		parser_loop
	rec_parser_loop_end:

	# panic if expected ] not found
	cmpb	$93, -0x1(%rdi)
	jne		no_closed_par

	movq	-0x10(%rbp), %rax
	orq		-0x20(%rbp), %rax
	cmpq	$0, %rax
	jne		rec_parser_no_optimise

rec_parser_optimise:
	call	save_mult
	call	save_mult_add
	# set ] jump offset
	movq	-0x8(%rbp), %rax
	movl	%r9d, -0x4(%r8, %rax)
	subl	%eax, -0x4(%r8, %rax)

	movq	%rbp, %rsp
	popq	%rbp
	ret

rec_parser_no_optimise:
	call	save_add
	call	save_move
	call	save_close
	# set [ jump offset
	movq	-0x8(%rbp), %rax
	movl	%r9d, -0x4(%r8, %rax)
	subl	%eax, -0x4(%r8, %rax)
	# set ] jump offset
	movl	%eax, -0x4(%r8, %r9)
	subl	%r9d, -0x4(%r8, %r9)

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

# stops the program and shows an error
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

parser_loop:
	movb	(%rdi), %cl
	movb	ascii_table(%rcx), %cl
	movq	jump_table(%rcx), %rax
	incq	%rdi
	jmp		*%rax
	
	parse_less:
		decq	-0x10(%rbp)
		jmp		parser_loop
	parse_greater:
		incq	-0x10(%rbp)
		jmp		parser_loop

	parse_plus:
		movq	-0x10(%rbp), %rax
		cmpq	0x8(%rsp), %rax
		je		parse_plus_reuse
			pushq	%rax
			pushq	$0
		parse_plus_reuse:
		incq	(%rsp)
		jmp		parser_loop
	parse_minus:
		movq	-0x10(%rbp), %rax
		cmpq	0x8(%rsp), %rax
		je		parse_minus_reuse
			pushq	%rax
			pushq	$0
		parse_minus_reuse:
		decq	(%rsp)
		jmp		parser_loop
	
	parse_open:
		movq	$1, -0x20(%rbp)
		call	save_add
		call	save_move
		call	rec_parser
		jmp		parser_loop
	
	parse_dot:
		movq	$1, -0x20(%rbp)
		call	save_add
		call	save_write
		jmp		parser_loop
	parse_comma:
		movq	$1, -0x20(%rbp)
		call	save_add
		call	save_read
		jmp		parser_loop

	parser_loop_end:
	jmp		*-0x18(%rbp)
