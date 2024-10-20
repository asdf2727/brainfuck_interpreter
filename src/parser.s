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
	movq	$1, %r15
	movq	%r11, %rsp
	popq	%rbp
	ret

.global base_parser
base_parser:
	pushq	%rbp
	movq	%rsp, %rbp
	movq	%rsp, %r11	# panic stack position revert

	movq	$0, %rcx	# rcx should be 0 except for low byte

	pushq	$0						# begin loop position
	pushq	$0						# tape pointer offset
	pushq	$1						# optimise loop to mult (if 0)

	call	parser_loop

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
	movq	$2, %r15
	movq	%r11, %rsp
	popq	%rbp
	ret

rec_parser:
	pushq	%rbp
	movq	%rsp, %rbp

	pushq	$0						# begin loop position
	pushq	$0						# tape pointer offset
	pushq	$0						# optimise loop to mult (if 0)

	call	parser_loop

	# panic if expected ] not found
	cmpb	$93, -0x1(%rdi)
	jne		no_closed_par

	cmpq	$0, -0x18(%rbp)
	jne		rec_parser_no_optimise
	cmpq	$0, -0x10(%rbp)
	jne		rec_parser_save_open

rec_parser_optimise:
	cmpq	$0x30, %r9
	jge		rec_parser_optimise_with_open
		call	save_mult
		jmp		rec_parser_optimise_end
	rec_parser_optimise_with_open:
		call	save_open
		call	save_mult
		xchgq	%r8, 0x20(%r11)
		xchgq	%r9, 0x18(%r11)
		movq	-0x8(%rbp), %rdx
		movq	%r9, %rax
		subq	%rdx, %rax
		movl	%eax, -4(%r8, %rdx)		# set [ jump offset
		xchgq	%r8, 0x20(%r11)
		xchgq	%r9, 0x18(%r11)
	rec_parser_optimise_end:
	movq	%rbp, %rsp
	popq	%rbp
	ret

rec_parser_save_open:
	call	save_open
rec_parser_no_optimise:
	call	save_add_move
	call	save_close

	xchgq	%r8, 0x20(%r11)
	xchgq	%r9, 0x18(%r11)
	movq	-0x8(%rbp), %rdx
	movq	%r9, %rax
	subq	%rdx, %rax
	movl	%eax, -4(%r8, %rdx)		# set [ jump offset
	negq	%rax
	movl	%eax, -4(%r8, %r9)		# set ] jump offset
	xchgq	%r8, 0x20(%r11)
	xchgq	%r9, 0x18(%r11)

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

insert_add:
	movq	$-0x10, %rsi
	movq	-0x10(%rbp), %rdx
	insert_add_find_loop:
		addq	$0x10, %rsi
		cmpq	%r9, %rsi
		je		insert_add_new
		cmpq	%rdx, (%r8, %rsi)
		jl		insert_add_find_loop
	insert_add_found:

	cmpq	%rdx, (%r8, %rsi)
	je		insert_add_reuse
		movq	%r9, %rcx
		addq	$0x10, %r9
		call	stinc
		insert_add_new_loop:
			movq	-0x10(%r8, %rcx), %rax
			movq	%rax, (%r8, %rcx)
			movq	-0x8(%r8, %rcx), %rax
			movq	%rax, 0x8(%r8, %rcx)
			subq	$0x10, %rcx
			cmpq	%rsi, %rcx
			jg		insert_add_new_loop
		movq	$0, %rcx
		movq	%rdx, (%r8, %rsi)
		movq	$0, 0x8(%r8, %rsi)
	insert_add_reuse:
	ret
	
	insert_add_new:
	stpushq	%rdx
	stpushq	$0
	ret

disable_opt:
	cmpq	$0, -0x18(%rbp)
	jne		disable_opt_skip
		movq	$1, -0x18(%rbp)
		call	save_open
	disable_opt_skip:
	ret

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
		call	insert_add
		incq	0x8(%r8, %rsi)
		jmp		parser_loop
	parse_minus:
		call	insert_add
		decq	0x8(%r8, %rsi)
		jmp		parser_loop
	
	parse_open:
		call	disable_opt
		call	save_add_move
		call	rec_parser
		jmp		parser_loop
	
	parse_dot:
		call	disable_opt
		call	save_add
		call	save_write
		jmp		parser_loop
	parse_comma:
		call	disable_opt
		call	save_add
		call	save_read
		jmp		parser_loop

	parser_loop_end:
	ret

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

		movq	$0, %rcx

		jmp		parser_loop
