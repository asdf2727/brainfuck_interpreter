# %rdi - current char pointer
# stack - instruction buffer
# st (in the heap) - intermideary code result

.data

wrong_char_str:	.asciz	"This (%c) character is not part of the brainfuck language. Maybe you put in the wrong file?\n"
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
	movq	%r11, %rsp
	popq	%rbp
	ret

.global base_parser
base_parser:
	movq	%rbp, %r11	# panic stack position revert
	pushq	%rbp
	movq	%rsp, %rbp

	movq	$0, %rcx	# rcx should be 0 except for low byte

	pushq	$0						# begin loop position
	pushq	$0						# tape pointer offset
	pushq	$base_parser_end_loop	# ret address for parser_loop
	pushq	$1						# optimise loop to mult (if 0)

	# first add
	pushq	$0
	pushq	$0

	jmp		parser_loop
	base_parser_end_loop:

	# panic if not expected ] found
	cmpb	$93, -0x1(%rdi)
	je		no_open_par

	call	save_add
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
	movq	%r11, %rsp
	popq	%rbp
	ret

rec_parser:
	pushq	%rbp
	movq	%rsp, %rbp

	call	save_open

	pushq	%r9				# begin loop position
	pushq	$0				# tape pointer offset
	pushq	$rec_parser_end	# ret address for parser_loop
	pushq	$0				# optimise loop to mult (if 0)

	# first add
	pushq	$0
	pushq	$0

	jmp		parser_loop
	rec_parser_end:

	# panic if expected ] not found
	cmpb	$93, -0x1(%rdi)
	jne		no_closed_par

	call	save_add
	call	save_move
	call	save_close
	# set ] jump offset
	movq	-0x8(%rbp), %rax
	movl	%eax, -0x4(%r8, %r9)
	subl	%r9d, -0x4(%r8, %r9)
	# set [ jump offset
	movl	%r9d, -0x4(%r8, %rax)
	subl	%eax, -0x4(%r8, %rax)

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
.quad	parse_unknown
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
	pushq	(%rdi)
	call	stdel
	popq	%rsi
	movq	$wrong_char_str, %rdi
	call	printf_safe
	movq	%r11, %rsp
	popq	%rbp
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
		call	save_add
		call	save_move
		call	rec_parser
		jmp		parser_loop
	
	parse_dot:
		call	save_add
		call	save_write
		jmp		parser_loop
	parse_comma:
		call	save_add
		call	save_read
		jmp		parser_loop

	parser_loop_end:
	jmp		*-0x18(%rbp)

# --- SAVER ---

save_add:
	leaq	-0x28(%rbp), %rdx
	cmpq	%rdx, %rsp
	jge		save_add_end
	save_add_loop:
		cmpb	$0, -0x8(%rdx)
		je		save_add_loop_end
			movq	(%rdx), %rax
			movb	-0x8(%rdx), %cl
			#	addb	VAL, OFFSET(%rsi)
			addq	$7, %r9
			call	stinc
			movw	$0x8380, -7(%r8, %r9)
			movl	%eax, -5(%r8, %r9)
			movb	%cl, -1(%r8, %r9)
		save_add_loop_end:
		subq	$0x10, %rdx
		cmpq	%rdx, %rsp
		jl		save_add_loop
	save_add_end:
	movq	(%rsp), %rax
	leaq	-0x20(%rbp), %rsp
	pushq	$0
	pushq	$0
	jmp		*%rax

save_move:
	movq	-0x10(%rbp), %rax
	cmpq	$0, %rax
	je		save_move_end
		movq	$0, -0x10(%rbp)
		# 	addq	VAL, %rsi
		addq	$7, %r9
		call	stinc
		movb	$0x48, -7(%r8, %r9)
		movw	$0xC381, -6(%r8, %r9)
		movl	%eax, -4(%r8, %r9)
	save_move_end:
	ret

save_open:
	#	cmpb	$0, (%rsi)
	#	je		end_loop
	addq	$9, %r9
	call	stinc
	movl	$0x0F003B80, -9(%r8, %r9)
	movb	$0x84, -5(%r8, %r9)
	ret

save_close:
	#	cmpb	$0, (%rsi)
	#	je		end_loop
	addq	$9, %r9
	call	stinc
	movl	$0x0F003B80, -9(%r8, %r9)
	movb	$0x85, -5(%r8, %r9)
	ret

save_write:
	movq	-0x10(%rbp), %rax
	#	movq	$1, %rax
	#	leaq	OFFSET(%rbx), %rsi
	#	syscall
	addq	$13, %r9
	call	stinc
	movw	$0xC0C6, -13(%r8, %r9)
	movb	$0x01, -11(%r8, %r9)
	movl	$0x1D348D48, -10(%r8, %r9)
	movl	%eax, -6(%r8, %r9)
	movw	$0x050F, -2(%r8, %r9)
	ret

save_read:
	movq	-0x10(%rbp), %rax
	#	movq	$0, %rax
	#	leaq	OFFSET(%rbx), %rsi
	#	syscall
	addq	$13, %r9
	call	stinc
	movw	$0xC0C6, -13(%r8, %r9)
	movb	$0x00, -11(%r8, %r9)
	movl	$0x1D348D48, -10(%r8, %r9)
	movl	%eax, -6(%r8, %r9)
	movw	$0x050F, -2(%r8, %r9)
	ret

save_ret:
	stpushb	$0xC3	# near ret
	ret