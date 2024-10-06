# %rdi - current char pointer
# stack - command buffer
# st (in the heap) - intermideary code result

.data

wrong_char_str:	.asciz	"This (%c) character is not part of the brainfuck language. Maybe you put in the wrong file?\n"
few_par_str:	.asciz	"Expected closing paranthesis (]) not found until EOF. Good luck counting parantheses!\n"
many_par_str:	.asciz	"Unexpected closing paranthesis (]) found. Good luck counting parantheses!\n"

.text

.include "lib/inc/stk.s"
.include "lib/inc/utils.s"

# --- ERROR HANDLING ---

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

# found extra closed paranthesis
no_open_par:
	call	stdel
	movq	$many_par_str, %rdi
	call	printf_safe
	movq	%r11, %rsp
	popq	%rbp
	ret

# found EOF before closing all parantheses
no_closed_par:
	call	stdel
	movq	$few_par_str, %rdi
	call	printf_safe
	movq	%r11, %rsp
	popq	%rbp
	ret

# --- BASE PARSER ---

.data

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

.text

# parses the initial string, calling rec_solver for each paranthesis
.global base_parser
base_parser:
	movq	%rbp, %r11
	pushq	%rbp
	movq	%rsp, %rbp

	pushq	$0
	pushq	$0
	movq	$0, %rcx

base_parser_loop:
	movb	(%rdi), %cl
	movb	ascii_parse_table(%rcx), %cl
	movq	base_parse_table(%rcx), %rax
	incq	%rdi
	jmp		*%rax
	
	base_parse_less:
		cmpq	$0x08, 0x8(%rsp)
		je		base_parse_less_reuse
			pushq	$0x08
			pushq	$0
		base_parse_less_reuse:
		decq	(%rsp)
		jmp		base_parser_loop
	base_parse_greater:
		cmpq	$0x08, 0x8(%rsp)
		je		base_parse_greater_reuse
			pushq	$0x08
			pushq	$0
		base_parse_greater_reuse:
		incq	(%rsp)
		jmp		base_parser_loop
	
	base_parse_minus:
		cmpq	$0x10, 0x8(%rsp)
		je		base_parse_minus_reuse
			pushq	$0x10
			pushq	$0
		base_parse_minus_reuse:
		decq	(%rsp)
		jmp		base_parser_loop
	base_parse_plus:
		cmpq	$0x10, 0x8(%rsp)
		je		base_parse_plus_reuse
			pushq	$0x10
			pushq	$0
		base_parse_plus_reuse:
		incq	(%rsp)
		jmp		base_parser_loop
	
	base_parse_open:
		call	heap_saver
		call	rec_parser
		jmp		base_parser_loop
	
	base_parse_dot:
		pushq	$0x18
		pushq	$0x0
		jmp		base_parser_loop
	base_parse_comma:
		pushq	$0x20
		pushq	$0x0
		jmp		base_parser_loop
	
base_parser_done:
	cmpb	$93, -0x1(%rdi)
	je		no_open_par

	call	heap_saver

#	ret
	stpushb	$0xC3	# near ret

	movq	%rbp, %rsp
	popq	%rbp
	ret

# --- REC PARSER ---

.data

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

.text

# parses a paranthesis, calling itself recursively for each nrumbe
rec_parser:
	pushq	%rbp
	movq	%rsp, %rbp

	pushq	$0
	pushq	%r9
	
#	cmpb	$0, (%rax)
	stpushb	$0x80	# CMP r/m8, imm8
	stpushb	$0x38	# \7, [RAX]
	stpushb	$0		# ib
#	je		end_loop
	stpushb $0x0F	# near jump
	stpushb $0x84	# je
	stpushl	$0		# cd

rec_parser_loop:
	movb	(%rdi), %cl
	movb	ascii_parse_table(%rcx), %cl
	movq	rec_parse_table(%rcx), %rax
	incq	%rdi
	jmp		*%rax

	rec_parse_less:
		cmpq	$0x08, 0x8(%rsp)
		je		rec_parse_less_reuse
			pushq	$0x08
			pushq	$0
		rec_parse_less_reuse:
		decq	(%rsp)
		jmp		rec_parser_loop
	rec_parse_greater:
		cmpq	$0x08, 0x8(%rsp)
		je		rec_parse_greater_reuse
			pushq	$0x08
			pushq	$0
		rec_parse_greater_reuse:
		incq	(%rsp)
		jmp		rec_parser_loop
	
	rec_parse_plus:
		cmpq	$0x10, 0x8(%rsp)
		je		rec_parse_plus_reuse
			pushq	$0x10
			pushq	$0
		rec_parse_plus_reuse:
		incq	(%rsp)
		jmp		rec_parser_loop
	rec_parse_minus:
		cmpq	$0x10, 0x8(%rsp)
		je		rec_parse_minus_reuse
			pushq	$0x10
			pushq	$0
		rec_parse_minus_reuse:
		decq	(%rsp)
		jmp		rec_parser_loop
	
	rec_parse_open:
		call	heap_saver
		call	rec_parser
		jmp		rec_parser_loop
	
	rec_parse_dot:
		pushq	$0x18
		pushq	$0x0
		jmp		rec_parser_loop
	rec_parse_comma:
		pushq	$0x20
		pushq	$0x0
		jmp		rec_parser_loop

rec_parser_done:
	cmpb	$93, -0x1(%rdi)
	jne		no_closed_par

	call	heap_saver

#	cmpb	$0, (%rax)
	stpushb	$0x80	# CMP r/m8, imm8
	stpushb	$0x38	# \7, [RAX]
	stpushb	$0		# ib

	movq	-0x10(%rbp), %rax
	leaq	5(%rax), %rdx
	subq	%r9, %rax
	addq	$3, %rax

#	jne		begin_loop
	stpushb $0x0F	# near jump
	stpushb $0x85	# jne
	stpushl	%eax	# cd

	# fix je from the beginning of the loop
	negq	%rax
	movl	%eax, (%r8, %rdx)

	movq	%rbp, %rsp
	popq	%rbp
	ret

# --- SAVER ---

.data

save_table:
.quad	heap_saver_end	# 0x00
.quad	save_move		# 0x08
.quad	save_add		# 0x10
.quad	save_write		# 0x18
.quad	save_read		# 0x20

write_code:
	pushq	%rax
	movq	%rax, %rsi		# from rax
	movq	$1, %rax		# write
	movq	$1, %rdi		# to stdout
	movq	$1, %rdx		# 1 char
	syscall
	popq	%rax
write_code_end:

read_code:
	# TODO read from stdint with syscall
read_code_end:

.text

heap_saver:
	pushq	(%rsp)
	movq	$0x00, 0x8(%rsp)
	leaq	-0x10(%rbp), %rdx

heap_saver_loop:
	subq	$0x10, %rdx
	movq	0x8(%rdx), %rax
	movq	save_table(%rax), %rax
	jmp		*%rax

	save_move:
	#	subq	%rax, \VAL
		stpushb	$0x48	# REX
		stpushb	$0x2D	# SUB RAX, imm32
		movq	(%rdx), %rax
		stpushl	%eax	# id
		jmp		heap_saver_loop

	save_add:
	#	addb	(%rax), \VAL
		# stpushb	$0x48	# REX
		stpushb	$0x80	# ADD r/m8, imm8
		stpushb	$0x00	# \0, [RAX]
		movq	(%rdx), %rax
		stpushb	%al		# ib
		jmp		heap_saver_loop

	save_write:
		pushq	%rdi
			leaq	write_code_end - write_code(%r9), %rdi
			call	stresize
			leaq	write_code - write_code_end(%r8, %r9), %rdi
			movq	$(write_code_end - write_code), %rcx
			movq	$write_code, %rsi
			rep movsb
		popq	%rdi
		jmp		heap_saver_loop

	save_read:
		pushq	%rdi
			leaq	read_code_end - read_code(%r9), %rdi
			call	stresize
			leaq	read_code - read_code_end(%r8, %r9), %rdi
			movq	$(read_code_end - read_code), %rcx
			movq	$read_code, %rsi
			rep movsb
		popq	%rdi
		jmp		heap_saver_loop

heap_saver_end:
	movq	(%rsp), %rax
	leaq	-0x10(%rbp), %rsp
	jmp		*%rax
