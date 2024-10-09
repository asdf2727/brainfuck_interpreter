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
	
	pushq	%r11
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
	popq	%r11

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

# --- SAVER ---

save_add:
	leaq	-0x28(%rbp), %rdx
	save_add_loop:
		cmpb	$0, -0x8(%rdx)
		je		save_add_loop_end
			movq	(%rdx), %rax
			movb	-0x8(%rdx), %cl
			#	addb	VAL, OFFSET(%rbx)
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
		# 	addq	VAL, %rbx
		addq	$7, %r9
		call	stinc
		movb	$0x48, -7(%r8, %r9)
		movw	$0xC381, -6(%r8, %r9)
		movl	%eax, -4(%r8, %r9)
	save_move_end:
	ret

save_mult:
	movq	$0, %rax
	leaq	-0x28(%rbp), %rdx
	save_mult_loop:
		cmpb	$0, (%rdx)
		jne		save_mult_loop_skip
			addq	-0x8(%rdx), %rax
		save_mult_loop_skip:
		subq	$0x10, %rdx
		cmpq	%rdx, %rsp
		jl		save_mult_loop
	save_mult_loop_end:
	andq	$0xff, %rax
	movw	mult_table(, %rax, 2), %cx
	
	save_mult_write:
	#	movl	(%rbx), %esi
	stpushw	$0x338B
	cmpb	$0, %cl
	je		save_mult_no_shift
		#	shrl	%esi, shift
		addq	$3, %r9
		call	stinc
		movw	$0xEEC1, -3(%r8, %r9)
		movb	%cl, -1(%r8, %r9)
	save_mult_no_shift:
	shrq	$8, %rcx
	cmpb	$1, %cl
	je		save_mult_no_mult
		#	imull	mult, %esi, %esi
		addq	$3, %r9
		call	stinc
		movw	$0xF66B, -3(%r8, %r9)
		movb	%cl, -1(%r8, %r9)
	save_mult_no_mult:
	ret

save_mult_add:
	leaq	-0x28(%rbp), %rdx
	save_mult_add_loop:
		cmpb	$0, -0x8(%rdx)
		je		save_mult_add_loop_end
			movq	(%rdx), %rax
			movb	-0x8(%rdx), %cl
			#	imull	VAL, %esi, %ecx
			#	subb	%cl, OFFSET(%rbx)
			addq	$9, %r9
			call	stinc
			movw	$0xCE6B, -9(%r8, %r9)
			movb	%cl, -7(%r8, %r9)
			movw	$0x8B28, -6(%r8, %r9)
			movl	%eax, -4(%r8, %r9)
		save_mult_add_loop_end:
		subq	$0x10, %rdx
		cmpq	%rdx, %rsp
		jl		save_mult_add_loop
	save_mult_add_end:
	movq	(%rsp), %rax
	jmp		*%rax

save_open:
	#	cmpb	$0, (%rbx)
	#	je		end_loop
	addq	$9, %r9
	call	stinc
	movl	$0x0F003B80, -9(%r8, %r9)
	movb	$0x84, -5(%r8, %r9)
	ret

save_close:
	#	cmpb	$0, (%rbx)
	#	je		end_loop
	addq	$9, %r9
	call	stinc
	movl	$0x0F003B80, -9(%r8, %r9)
	movb	$0x85, -5(%r8, %r9)
	ret

save_write:
	movq	-0x10(%rbp), %rax
	#	movq	$1, %al
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

.data

mult_table:
.quad   0xab00010001000100
.quad   0xb7002b00cd000100
.quad   0xa3004d0039000100
.quad   0xef003700c5002b00
.quad   0x1b003900f1000100
.quad   0xa70023003d000d00
.quad   0x1300450029000b00
.quad   0xdf006f0035003700
.quad   0x8b007100e1000100
.quad   0x97001b00ad003900
.quad   0x83003d0019000d00
.quad   0xcf002700a5002300
.quad   0xfb002900d1000b00
.quad   0x870013001d000500
.quad   0xf300350009001700
.quad   0xbf005f0015002f00
.quad   0x6b006100c1000100
.quad   0x77000b008d003100
.quad   0x63002d00f9001900
.quad   0xaf00170085001b00
.quad   0xdb001900b1000d00
.quad   0x67000300fd003d00
.quad   0xd3002500e9000300
.quad   0x9f004f00f5002700
.quad   0x4b005100a1000300
.quad   0x57007b006d002900
.quad   0x43001d00d9000500
.quad   0x8f00070065001300
.quad   0xbb00090091000700
.quad   0x47007300dd003500
.quad   0xb3001500c9000f00
.quad   0x7f003f00d5001f00
.quad   0x2b00410081000100
.quad   0x37006b004d002100
.quad   0x23000d00b9001100
.quad   0x6f00770045000b00
.quad   0x9b00790071000900
.quad   0x27006300bd002d00
.quad   0x93000500a9001b00
.quad   0x5f002f00b5001700
.quad   0xb00310061000500
.quad   0x17005b002d001900
.quad   0x3007d0099001d00
.quad   0x4f00670025000300
.quad   0x7b00690051000300
.quad   0x70053009d002500
.quad   0x7300750089000700
.quad   0x3f001f0095000f00
.quad   0xeb00210041000300
.quad   0xf7004b000d001100
.quad   0xe3006d0079000900
.quad   0x2f00570005003b00
.quad   0x5b00590031000500
.quad   0xe70043007d001d00
.quad   0x5300650069001300
.quad   0x1f000f0075000700
.quad   0xcb00110021000700
.quad   0xd7003b00ed000900
.quad   0xc3005d0059001500
.quad   0xf004700e5003300
.quad   0x3b00490011000f00
.quad   0xc70033005d001500
.quad   0x3300550049001f00
.quad   0xff007f0055003f00
