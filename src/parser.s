# %rdi - current char pointer
# stack - command buffer
# st (in the heap) - intermideary code result

.data

wrong_char_str:	.asciz	"This (%c) character is not part of the brainfuck language. Maybe you put in the wrong file?\n"
few_par_str:	.asciz	"Expected closing paranthesis (]) not found until EOF. Good luck counting parantheses!\n"
many_par_str:	.asciz	"Unexpected closing paranthesis (]) found. Good luck counting parantheses!\n"

.text

.include "lib/inc/stk.s"

# --- ERROR HANDLING ---

# stops the program and shows an error
parse_unknown:
	pushq	(%rdi)
	call	stdel
	popq	%rsi
	movq	$wrong_char_str, %rdi
	call	printf_safe
	movq	%rbp, %rsp
	popq	%rbp
	ret

# found extra closed paranthesis
no_open_par:
	call	stdel
	movq	$many_par_str, %rdi
	call	printf_safe
	movq	%rbp, %rsp
	popq	%rbp
	ret

# found EOF before closing all parantheses
no_closed_par:
	call	stdel
	movq	$few_par_str, %rdi
	call	printf_safe
	movq	%rbp, %rsp
	popq	%rbp
	ret

# --- BASE PARSER ---

# parses the initial string, calling rec_solver for each paranthesis
.global base_parser
base_parser:
	pushq	%rbx

	pushq	$0
	pushq	$0
	movq	%rsp, %rbx
	movq	$0, %rcx
	jmp		base_parser_loop

	base_parse_comma:
		pushq	$0x10
		pushq	$0x0
		jmp		base_parser_loop
	
	base_parse_plus:
		cmpq	$0x28, 0x8(%rsp)
		je		base_parse_plus_reuse
			pushq	$0x28
			pushq	$0
		base_parse_plus_reuse:
		incq	(%rsp)
		jmp		base_parser_loop
	
	base_parse_less:
		cmpq	$0x30, 0x8(%rsp)
		je		base_parse_less_reuse
			pushq	$0x30
			pushq	$0
		base_parse_less_reuse:
		decq	(%rsp)
		jmp		base_parser_loop

base_parser_loop:
	movb	(%rdi), %cl
	movb	ascii_parse_table(%rcx), %cl
	movq	base_parse_table(%rcx), %rax
	incq	%rdi
	jmp		*%rax
	
	base_parse_greater:
		cmpq	$0x30, 0x8(%rsp)
		je		base_parse_greater_reuse
			pushq	$0x30
			pushq	$0
		base_parse_greater_reuse:
		incq	(%rsp)
		jmp		base_parser_loop
	
	base_parse_minus:
		cmpq	$0x28, 0x8(%rsp)
		je		base_parse_minus_reuse
			pushq	$0x28
			pushq	$0
		base_parse_minus_reuse:
		decq	(%rsp)
		jmp		base_parser_loop
	
	base_parse_open:
		call	heap_saver
		call	rec_parser
		jmp		base_parser_loop
	
	base_parse_dot:
		pushq	$0x18
		pushq	$0x0
		jmp		base_parser_loop
	
base_parser_done:
	decq	%rdi
	cmpb	$93, (%rdi)
	je		no_open_par

	pushq	$0x00
	pushq	$0
	call	heap_saver

	leaq	0x10(%rbx), %rsp
	popq	%rbx
	ret

base_parse_table:
.quad	parse_unknown
.quad	base_parser_loop
.quad	base_parse_plus
.quad	base_parse_comma
.quad	base_parse_minus
.quad	base_parse_dot
.quad	base_parse_less
.quad	base_parse_greater
.quad	base_parse_open
.quad	base_parser_done

ascii_parse_table:
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

# --- REC PARSER ---

# parses a paranthesis, calling itself recursively for each nrumbe
rec_parser:
	pushq	%rbx

	pushq	%r9
	pushq	$1
	pushq	$0
	movq	%rsp, %rbx
	movq	$0, %rcx
	jmp		rec_parser_loop

	rec_parse_dot:
		movq	$0, 0x8(%rbx)
		pushq	$0x18
		pushq	$0x0
		jmp		rec_parser_loop
	
	rec_parse_plus:
		cmpq	$0x28, 0x8(%rsp)
		je		rec_parse_plus_reuse
			pushq	$0x28
			pushq	$0
		rec_parse_plus_reuse:
		incq	(%rsp)
		jmp		rec_parser_loop

	rec_parse_less:
		cmpq	$0x30, 0x8(%rsp)
		je		rec_parse_less_reuse
			pushq	$0x30
			pushq	$0
		rec_parse_less_reuse:
		decq	(%rsp)
		decq	(%rbx)
		jmp		rec_parser_loop

rec_parser_loop:
	movb	(%rdi), %cl
	movb	ascii_parse_table(%rcx), %cl
	movq	rec_parse_table(%rcx), %rax
	incq	%rdi
	jmp		*%rax

	rec_parse_greater:
		cmpq	$0x30, 0x8(%rsp)
		je		rec_parse_greater_reuse
			pushq	$0x30
			pushq	$0
		rec_parse_greater_reuse:
		incq	(%rsp)
		incq	(%rbx)
		jmp		rec_parser_loop
	
	rec_parse_minus:
		cmpq	$0x28, 0x8(%rsp)
		je		rec_parse_minus_reuse
			pushq	$0x28
			pushq	$0
		rec_parse_minus_reuse:
		decq	(%rsp)
		jmp		rec_parser_loop
	
	rec_parse_open:
		movq	$0, 0x8(%rbx)
		call	heap_saver
		call	rec_parser
		jmp		rec_parser_loop
	
	rec_parse_comma:
		movq	$0, 0x8(%rbx)
		pushq	$0x10
		pushq	$0x0
		jmp		rec_parser_loop

rec_parser_done:
	cmpb	$93, -0x1(%rdi)
	jne		no_closed_par

	cmpq	$0, (%rbx)
	jne		rec_parser_no_optimise
	cmpq	$0, 0x8(%rbx)
	je		rec_parser_no_optimise
	
rec_parser_optimise:
	call	heap_saver
	leaq	0x18(%rbx), %rsp
	popq	%rbx
	ret

rec_parser_no_optimise:
	movq	$0, 0x8(%rbx)
	call	heap_saver
	stpushb	$0x28
	movq	0x10(%rbx), %rax
	movq	%r9, 0x1(%r8, %rax)
	addq	$0x9, %rax
	stpushq	%rax
	leaq	0x18(%rbx), %rsp
	popq	%rbx
	ret

rec_parse_table:
.quad	parse_unknown
.quad	rec_parser_loop
.quad	rec_parse_plus
.quad	rec_parse_comma
.quad	rec_parse_minus
.quad	rec_parse_dot
.quad	rec_parse_less
.quad	rec_parse_greater
.quad	rec_parse_open
.quad	rec_parser_done

# --- SAVER ---

heap_saver:
	pushq	(%rsp)
	movq	$0x08, 0x8(%rsp)
	movq	%rbx, %rdx
	jmp		heap_saver_loop

	save_write:
		stpushb $0x10
		jmp		heap_saver_loop
	
	save_add:
		stpushb	$0x38
		movq	(%rdx), %rax
		stpushb	%al
		jmp		heap_saver_loop

heap_saver_loop:
	subq	$0x10, %rdx
	movq	0x8(%rdx), %rax
	movq	save_table(%rax), %rax
	jmp		*%rax
	
	save_move:
		stpushb	$0x40
		movq	(%rdx), %rax
		stpushq	%rax
		jmp		heap_saver_loop
	
	save_par:
		stpushb $0x20
		movq	(%rdx), %rax
		stpushb	%al
		jmp		heap_saver_loop

	save_read:
		stpushb	$0x08
		jmp		heap_saver_loop

save_exit:
	stpushb	$0x00
heap_saver_end:
	movq	(%rsp), %rax
	movq	%rbx, %rsp
	jmp		*%rax

save_table:
.quad	save_exit		# 0x00
.quad	heap_saver_end	# 0x08
.quad	save_read		# 0x10
.quad	save_write		# 0x18
.quad	save_par		# 0x20
.quad	save_add		# 0x28
.quad	save_move		# 0x30
