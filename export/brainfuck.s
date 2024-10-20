# This is an automated export version of the project, not meant for editing or reading.
# ## TODO

# - [x] use addb with 0x0(%rbx) before a jump if you can to avoid using a cmpb
# - [x] also set 0x0(%rbx) to $0 when multiplying to avoid wasted instructions
# - [x] bring back multiplier to optimise loops
# eventually only optimise loops with +- 1 in checked pointer to reduce
# - [x] remove imul operations whenever possible
# - [x] prepare syscall registers IN ADVANCE to avoid wasting instructions on mov $1, %reg
# - [x] use offset for write/read instructions
# - [x] use buffering for output to avoid using syscalls too many times
# - [ ] use registers for variables where possible
# - [x] don't use a je before optimised loops if loops are short
# - [x] skip calculating multiplier if no values depend on it
# - [ ] use xmm for additions if enough adds are close together (preferably alligned)

# # RANT 1

# Hi! I'm writing this at 12:35 AM, 16/09/2024 in the first day of coding this monstruosity.

# This is supposed to be an efficient brainfuck interpreter that:

# 1. parses the entire text and optimizes everything it can
# 2. saves the optimised code as an "intermediary" language in the heap using the heap stack I made myself (see stk.s)
# 3. runs the intermediary code super fast, using a circular buffer for the memory tape (see cbuf.s)

# Since for now I'm still working on the parser I don't know exactly how it'll end up but here are some optimiztions that i thought of:

# - [x] run all consecutive +/- and >/< operations in a single operation. This might actually be the biggest optimization since a normal program is full of long strings of the same symbol
# - [x] run loops that:
# 	1. don't have other loops inside them
# 	2. start and end at the same ptr position
# 	3. don't have I/O operations
# as a single run, multiplying the normal +/- operation by the number of repetitions
# e.g. `[<++++>-]` would be converted to `*(ptr-1) += 4 * *(ptr); *(ptr) = 0`
# this should help with a lot of tedious operations of this kind that always pop up in brainfuck programs
# - [x] make the "intermediary" language actually just hex instructions and run it natively
# this would make it blazing fast, but it would also burn my brain trying to understand how to write and run code in the heap

# These are all the ideas I had until now, but we'll see how many end up in the final version

# # RANT 2

# I'm about to rant for a few paragraphs, for useful stuff see [TODO](#todo).

# Hi again! 08/10/2024, nearly a month later, I realize that this project was more addictive than I thought. Initially I just planned for it to be a fun adventure to see how fast I can get the code to run, and in the beginning it was indeed fun.

# The problem arised some time ago with the 'cheese' major version of the program, which tried to implement. The second optimization (the multiplication vs loop one) and ended up being slower. Hooray! That was one week of my life wasted and caused me a temporary burnout.

# After that, I managed to get the JIT compilation working, over the course of which I learned a lot about how assembly is actually represented in hex code (I managed to find the 2 chapters in the 2000 page Intel manual that I was interested in). After I got it to work, I found the one moment of happiness working on this project, due to a x6 speed increase for the Mandelbrot script.

# After that I did one small optimization and called it a day. I mean, I was pretty happy with my results. I planned to start working on a renderer for the 11th assignment, the x86 game.

# Only, that one small optimization actually didn't help at all. Moreover, when I tested it with another script, the Hanoi one, it ended up being SIGNIFICANTLY slower. This made zero sense because I simply reduced the number of instructions in my compiled code. Instead of doing `addb $1, %rax; addb $1, (%rax); addb $1, %rax; addb $1, (%rax)`... I just did `addb $1, 0x1(%rax); addb $1, 0x2(%rax);` and added an `addb $whatever, %rax` at the end. It does exactly the same things, just with half of the instructions, but it's slower.

# I don't know for the life of me why this happens, and I more or less accepted it as just the lottery of how your specific program runs, but now I'm at a point where I NEED to make it faster to restore what's left of my pride. It's not about liking it anymore, I'm just addicted to optimizations. And now here we are:

# Thank you for allowing me to share my struggles with this project, and it might also help you to learn a valuable lesson:

# **ALWAYS TEST AND BENCHMARK ANY OPTIMIZATION TO MAKE SURE IT'S ACTUALLY FASTER!** Only god and the guys at intel know how the processor works!
.macro stpushq SRC
	addq	$0x8, %r9
	call	stinc
	movq	\SRC, -0x8(%r8, %r9)
.endm
.macro stpushl SRC
	addq	$0x4, %r9
	call	stinc
	movl	\SRC, -0x4(%r8, %r9)
.endm
.macro stpushw SRC
	addq	$0x2, %r9
	call	stinc
	movw	\SRC, -0x2(%r8, %r9)
.endm
.macro stpushb SRC
	addq	$0x1, %r9
	call	stinc
	movb	\SRC, -0x1(%r8, %r9)
.endm
.macro stpopq DST
	subq	$0x8, %r9
	movq	(%r8, %r9), \DST
	call	stdec
.endm
.macro stpopl DST
	subq	$0x4, %r9
	movl	(%r8, %r9), \DST
	call	stdec
.endm
.macro stpopw DST
	subq	$0x2, %r9
	movw	(%r8, %r9), \DST
	call	stdec
.endm
.macro stpopb DST
	subq	$0x1, %r9
	movb	(%r8, %r9), \DST
	call	stdec
.endm
.macro caller_save
	pushq   %rax
	pushq   %rcx
	pushq   %rdx
	pushq   %rdi
	pushq   %rsi
	pushq   %r8
	pushq   %r9
	pushq   %r10
	pushq   %r11
.endm
.macro caller_restore
	popq    %r11
	popq    %r10
	popq    %r9
	popq    %r8
	popq    %rsi
	popq    %rdi
	popq    %rdx
	popq    %rcx
	popq    %rax
.endm
.macro callee_save
	pushq   %rbx
	pushq   %r12
	pushq   %r13
	pushq   %r14
	pushq   %r15
.endm
.macro callee_restore
	popq    %r15
	popq    %r14
	popq    %r13
	popq    %r12
	popq    %rbx
.endm
.macro allign_stack size
	movq    %rsp, %rax
	subq    $0x8, %rax
	andq    \size, %rax
	subq    %rax, %rsp
	pushq   %rsp
	addq    %rax, (%rsp)
.endm
.macro offset_stack size, offset
	movq    %rsp, %rax
	subq    $0x8, %rax
	subq    \offset, %rax
	andq    \size, %rax
	subq    %rax, %rsp
	pushq   %rsp
	addq    %rax, (%rsp)
.endm
.macro printf_debug	SRC
	caller_save
	movq	\SRC, %rsi
	movq    $debug_out, %rdi
	call    printf_safe
	caller_restore
.endm
.text
stinit:
	movq	$0x10, %rdi
	call	malloc
	movq	%rax, %r8
	movq	$0, %r9
	movq	$0xf, %r10
	ret
stdel:
	movq	%r8, %rdi
	call	free
	ret
stresize:
	movq	%r9, %rsi
	cmpq	%rdi, %rsi
	cmovg	%rdi, %rsi
	addq	$7, %rsi
	shrq	$3, %rsi
	movq	%rdi, %r9
	bsrq	%rdi, %rcx
	movq	$2, %rdi
	shlq	%cl, %rdi
	leaq	-1(%rdi), %rcx
	cmpq	%rcx, %r10
	jne		strecast
	ret
stinc:
	cmpq	%r10, %r9
	jle		stinc_norecast
		pushq	%rdi
		pushq	%rsi
		leaq	1(%r10), %rdi
		movq	%rdi, %rsi
		shlq	$1, %rdi
		shrq	$3, %rsi
		call	strecast
		popq	%rsi
		popq	%rdi
	stinc_norecast:
	ret
stdec:
	push	%rdi
	leaq	1(%r10), %rdi
	shrq	$2, %rdi
	cmpq	%rdi, %r9
	jg		stdec_norecast
	cmpq	$0xf, %r10
	jle		stdec_norecast
		pushq	%rsi
		movq	%rdi, %rsi
		shlq	$1, %rdi
		shrq	$3, %rsi
		call	strecast
		popq	%rsi
	stdec_norecast:
	popq	%rdi
	ret
strecast:
	pushq	%rax
	pushq	%rcx
	pushq	%rdx
	pushq	%r11
	pushq	%rdi
	pushq	%r9
		pushq	%r8
		pushq	%rsi
			call	malloc
		popq	%rcx
		popq	%rsi
		movq	%rax, %rdi
		movq	%rsi, %rdx
		rep	movsq
		movq	%rdx, %rdi
		pushq	%rax
			call	free
		popq	%r8
	popq	%r9
	popq	%r10
	decq	%r10
	popq	%r11
	popq	%rdx
	popq	%rcx
	popq	%rax
	ret
.data
debug_out: .asciz "DEBUG: %ld\n"
.text
scanf_safe:
	allign_stack $0xf
	xorq	%rax, %rax
	call	scanf
	popq	%rsp 
	ret
printf_safe:
	allign_stack $0x0f
	xorq	%rax, %rax
	call	printf
	popq	%rsp 
	ret
.data
few_par_str:	.asciz	"Expected closing paranthesis (]) not found until EOF. Good luck counting parantheses!\n"
many_par_str:	.asciz	"Unexpected closing paranthesis (]) found. Good luck counting parantheses!\n"
.text
no_open_par:
	call	stdel
	movq	$many_par_str, %rdi
	call	printf_safe
	movq	$1, %r15
	movq	%r11, %rsp
	popq	%rbp
	ret
base_parser:
	pushq	%rbp
	movq	%rsp, %rbp
	movq	%rsp, %r11	
	movq	$0, %rcx	
	pushq	$0						
	pushq	$0						
	pushq	$1						
	call	parser_loop
	cmpb	$93, -0x1(%rdi)
	je		no_open_par
	call	save_ret
	movq	%rbp, %rsp
	popq	%rbp
	ret
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
	pushq	$0						
	pushq	$0						
	pushq	$0						
	call	parser_loop
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
		movl	%eax, -4(%r8, %rdx)		
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
	movl	%eax, -4(%r8, %rdx)		
	negq	%rax
	movl	%eax, -4(%r8, %r9)		
	xchgq	%r8, 0x20(%r11)
	xchgq	%r9, 0x18(%r11)
	movq	%rbp, %rsp
	popq	%rbp
	ret
.data
ascii_table:
.byte	0x48	
.skip	8, 0
.byte	0x8		
.byte	0x8		
.skip	21, 0
.byte	0x8		
.skip	10, 0
.byte	0x10	
.byte	0x18	
.byte	0x20	
.byte	0x28	
.skip	13, 0
.byte	0x30	
.skip	1, 0
.byte	0x38	
.skip	28, 0
.byte	0x40	
.skip	1, 0
.byte	0x48	
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
		call	save_add_move
		call	save_write
		jmp		parser_loop
	parse_comma:
		call	disable_opt
		call	save_add_move
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
.data
TP_add:	.quad	0
.text
.macro stswap
	xchgq	%r8, 0x20(%r11)
	xchgq	%r9, 0x18(%r11)
	xchgq	%r10, 0x10(%r11)
.endm
sanitise_add:
	movq	$0, TP_add
	movq	-0x10(%rbp), %rbx
	movq	$0, %rdx
	movq	$0, %rsi
	cmpq	%rsi, %r9
	je		sanitise_add_end
	sanitise_add_loop:
		cmpb	$0, 0x8(%r8, %rsi)
		je		sanitise_add_loop_end
			cmpq	%rbx, (%r8, %rsi)
			jne		sanitise_add_other
				movq	0x8(%r8, %rsi), %rax
				movq	%rax, TP_add
				jmp		sanitise_add_loop_end
			sanitise_add_other:
				movq	(%r8, %rsi), %rax
				movq	%rax, (%r8, %rdx)
				movq	0x8(%r8, %rsi), %rax
				movq	%rax, 0x8(%r8, %rdx)
				addq	$0x10, %rdx
		sanitise_add_loop_end:
		addq	$0x10, %rsi
		cmpq	%rsi, %r9
		jne		sanitise_add_loop
	sanitise_add_end:
	movq	%rdx, %r9
	ret
write_add:
	movq	0x20(%r11), %rsi
	movq	0x18(%r11), %rdx
	cmpq	$0, %rdx
	je		write_add_end
	addq	%rsi, %rdx
	write_add_loop:
		movq	(%rsi), %rax
		movb	0x8(%rsi), %cl
		addq	$7, %r9
		call	stinc
		movw	$0x8380, -7(%r8, %r9)
		movl	%eax, -5(%r8, %r9)
		movb	%cl, -1(%r8, %r9)
		write_add_loop_end:
		addq	$0x10, %rsi
		cmpq	%rdx, %rsi
		jne		write_add_loop
	write_add_end:
	movq	$0, 0x18(%r11)
	ret
save_add:
	call	sanitise_add
	stswap
	call	write_add
	movb	TP_add, %cl
	cmpb	$0, %cl
	je		save_add_skip_last
		movq	-0x10(%rbp), %rax
		addq	$7, %r9
		call	stinc
		movw	$0x8380, -7(%r8, %r9)
		movl	%eax, -5(%r8, %r9)
		movb	%cl, -1(%r8, %r9)
	save_add_skip_last:
	stswap
	ret
save_add_move:
	call	sanitise_add
	stswap
	call	write_add
	movq	-0x10(%rbp), %rax
	cmpq	$0, %rax
	je		save_add_move_skip_move
		movq	$0, -0x10(%rbp)
		addq	$7, %r9
		call	stinc
		movl	$0x00C38148, -7(%r8, %r9)
		movl	%eax, -4(%r8, %r9)
	save_add_move_skip_move:
	movb	TP_add, %cl
	cmpb	$0, %cl
	je		save_add_move_skip_last
		addq	$3, %r9
		call	stinc
		movw	$0x0380, -3(%r8, %r9)
		movb	%cl, -1(%r8, %r9)
	save_add_move_skip_last:
	stswap
	ret
mult_optimise:
	negb	%cl
	pushq	$1
	mult_optimise_tests:
		addq	$8, %rax
		cmpb	$0, %cl
		je		mult_optimise_done
		addq	$8, %rax
		cmpb	$1, %cl
		je		mult_optimise_done
		addq	$8, %rax
		leaq	-1(%rcx), %rbx
		andb	%cl, %bl
		cmpb	$0, %bl
		je		mult_optimise_done
	subq	$24, %rax
	cmpq	$0, (%rsp)
	je		mult_optimise_done
	negb	%cl
	movq	$0, (%rsp)
	jmp		mult_optimise_tests
	mult_optimise_done:
	popq	%rbx
	jmp		*(%rax)
.data
write_mult_table:
.quad	write_mult_default
.quad	write_mult_0
.quad	write_mult_1
.quad	write_mult_pow2
.text
write_mult:
	movb	TP_add, %cl
	movw	mult_table(, %rcx, 2), %cx
	movq	$1, %r12
	movq	$write_mult_table, %rax
	jmp		mult_optimise
	write_mult_default:
	addq	$3, %r9
	call	stinc
	movw	$0x0B6B, -3(%r8, %r9)
	movb	%cl, -1(%r8, %r9)
	jmp		write_mult_shift
	write_mult_pow2:
	bsfq	%rcx, %rdx
	subb	%dl, %ch
	write_mult_1:
	stpushw	$0x0B8B
	write_mult_shift:
	shrq	$8, %rcx
	cmpb	$0, %cl
	je		write_mult_no_shift
		addq	$3, %r9
		call	stinc
		movw	$0xF9C0, -3(%r8, %r9)
		movb	%cl, -1(%r8, %r9)
	write_mult_no_shift:
	jmp		write_mult_end
	write_mult_0:
	addq	$2, %r9
	call	stinc
	movw	$0xC933, -2(%r8, %r9)
	write_mult_end:
	xorq	%rbx, %r12
	ret
.data
save_mult_table:
.quad	save_mult_default
.quad	save_mult_0
.quad	save_mult_1
.quad	save_mult_pow2
.text
save_mult:
	call	sanitise_add
	pushq	$0
	stswap
	movq	0x20(%r11), %rsi
	movq	0x18(%r11), %rdx
	cmpq	$0, %rdx
	je		save_mult_end
	addq	%rsi, %rdx
	save_mult_loop:
		cmpq	$0, (%rsi)
		je		save_mult_loop_end
			cmpq	$0, (%rsp)
			jne		save_mult_skip_calc
				call	write_mult
				movq	$1, (%rsp)
			save_mult_skip_calc:
			movb	0x8(%rsi), %cl
			movq	$save_mult_table, %rax
			jmp		mult_optimise
			save_mult_default:
			addq	$3, %r9
			call	stinc
			movw	$0xC16B, -3(%r8, %r9)
			movb	%cl, -1(%r8, %r9)
			jmp		save_mult_write_add
			save_mult_pow2:
			bsfq	%rcx, %rax
			addq	$5, %r9
			call	stinc
			movl	$0xE0C0C888, -5(%r8, %r9)
			movb	%al, -1(%r8, %r9)
			save_mult_write_add:
			addq	$6, %r9
			call	stinc
			movw	$0x8300, -6(%r8, %r9)
			jmp		save_mult_write_end
			save_mult_1:
			addq	$6, %r9
			call	stinc
			movw	$0x8B00, -6(%r8, %r9)
			save_mult_write_end:
			movq	(%rsi), %rax
			movl	%eax, -4(%r8, %r9)
			xorq	%r12, %rbx
			imulq	$0x28, %rbx, %rbx
			addl	%ebx, -6(%r8, %r9)	
			save_mult_0:
		save_mult_loop_end:
		addq	$0x10, %rsi
		cmpq	%rdx, %rsi
		jne		save_mult_loop
	save_mult_end:
	movq	$0, 0x18(%r11)
	addq	$3, %r9
	call	stinc
	movw	$0x03C6, -3(%r8, %r9)
	movb	$0x00, -1(%r8, %r9)
	stswap
	addq	$0x8, %rsp
	ret
save_cmp:
	cmpb	$0, TP_add
	jne		save_cmp_skip
		addq	$3, %r9
		call	stinc
		movw	$0x3B80, -3(%r8, %r9)
		movb	$0x00, -1(%r8, %r9) 
	save_cmp_skip:
	ret
save_open:
	stswap
	call	save_cmp
	addq	$6, %r9
	call	stinc
	movl	$0x840F, -6(%r8, %r9)
	movq	%r9, -0x8(%rbp)
	stswap
	ret
save_close:
	stswap
	call	save_cmp
	addq	$6, %r9
	call	stinc
	movl	$0x850F, -6(%r8, %r9)
	stswap
	ret
save_write:
	stswap
	addq	$3, %r9
	call	stinc
	movw	$0xFF41, -3(%r8, %r9)
	movb	$0xD1, -1(%r8, %r9)
	stswap
	ret
save_read:
	stswap
	addq	$3, %r9
	call	stinc
	movw	$0xFF41, -3(%r8, %r9)
	movb	$0xD0, -1(%r8, %r9)
	stswap
	ret
save_ret:
	stswap
	addq	$4, %r9
	call	stinc
	movl	$0xC3D2FF41, -4(%r8, %r9)
	stswap
	ret
.data
mult_table:
.quad	0x00ab010100010800
.quad	0x00b7012b00cd0201
.quad	0x00a3014d00390301
.quad	0x00ef013700c5022b
.quad	0x001b013900f10401
.quad	0x00a70123003d020d
.quad	0x001301450029030b
.quad	0x00df016f00350237
.quad	0x008b017100e10501
.quad	0x0097011b00ad0239
.quad	0x0083013d0019030d
.quad	0x00cf012700a50223
.quad	0x00fb012900d1040b
.quad	0x00870113001d0205
.quad	0x00f3013500090317
.quad	0x00bf015f0015022f
.quad	0x006b016100c10601
.quad	0x0077010b008d0231
.quad	0x0063012d00f90319
.quad	0x00af01170085021b
.quad	0x00db011900b1040d
.quad	0x0067010300fd023d
.quad	0x00d3012500e90303
.quad	0x009f014f00f50227
.quad	0x004b015100a10503
.quad	0x0057017b006d0229
.quad	0x0043011d00d90305
.quad	0x008f010700650213
.quad	0x00bb010900910407
.quad	0x0047017300dd0235
.quad	0x00b3011500c9030f
.quad	0x007f013f00d5021f
.quad	0x002b014100810701
.quad	0x0037016b004d0221
.quad	0x0023010d00b90311
.quad	0x006f01770045020b
.quad	0x009b017900710409
.quad	0x0027016300bd022d
.quad	0x0093010500a9031b
.quad	0x005f012f00b50217
.quad	0x000b013100610505
.quad	0x0017015b002d0219
.quad	0x0003017d0099031d
.quad	0x004f016700250203
.quad	0x007b016900510403
.quad	0x00070153009d0225
.quad	0x0073017500890307
.quad	0x003f011f0095020f
.quad	0x00eb012100410603
.quad	0x00f7014b000d0211
.quad	0x00e3016d00790309
.quad	0x002f01570005023b
.quad	0x005b015900310405
.quad	0x00e70143007d021d
.quad	0x0053016500690313
.quad	0x001f010f00750207
.quad	0x00cb011100210507
.quad	0x00d7013b00ed0209
.quad	0x00c3015d00590315
.quad	0x000f014700e50233
.quad	0x003b01490011040f
.quad	0x00c70133005d0215
.quad	0x003301550049031f
.quad	0x00ff017f0055023f
.data
.equ	WRITE_BUFFER_SIZE, 0x10000
copy_funcs:
read_char:
	xorl	%eax, %eax
	movb	$1, %al
	movl	%eax, %edi
	syscall
	pushq	%rsi
		xorl	%eax, %eax
		xorl	%edi, %edi
		xorl	%edx, %edx
		movb	$1, %dl
		leaq	(%rbx), %rsi
		syscall
	popq	%rsi
	xorl	%edx, %edx
	ret
write_char:
	cmpl	$WRITE_BUFFER_SIZE, %edx
	jl		write_char_no_flush
	write_char_flush:
		xorl	%eax, %eax
		movb	$1, %al
		movl	%eax, %edi
		syscall
		xorl	%edx, %edx
	write_char_no_flush:
	movb	(%rbx), %al
	movb	%al, (%rsi, %rdx)
	incl	%edx
	ret
copy_funcs_end:
.text
runcode:
	pushq	%rbp
	pushq	%rbx
	movq	%rsp, %rbp
	subq	$0x18, %rsp
	movq	%r8, -0x8(%rbp)
	movq	%r9, -0x10(%rbp)
	movq	%r10, -0x18(%rbp)
	movq	$9, %rax
	movq	$0, %rdi
	movq	-0x10(%rbp), %rsi
	addq	$(copy_funcs_end - copy_funcs), %rsi
	movq	$3, %rdx
	movq	$33, %r10
	movq	$-1, %r8
	movq	$0, %r9
	syscall
	movq	%rax, %r8
	movq	$(copy_funcs_end - copy_funcs), %rcx
	movq	$copy_funcs, %rsi
	movq	%rax, %rdi
	rep movsb
	movq	-0x10(%rbp), %rcx
	movq	-0x8(%rbp), %rsi
	rep movsb
	movq	%rax, %rdi
	movq	$10, %rax
	movq	-0x10(%rbp), %rsi
	movq	$5, %rdx
	syscall
	subq	$0x80000, %rsp
	movq	$0x10000, %rcx
	movq	%rsp, %rdi
	movq	$0, %rax
	rep stosq
	movq	%rsp, %rbx
	subq	$WRITE_BUFFER_SIZE, %rsp
	movq	%rsp, %rsi
	movq	$0, %rdx
	leaq	write_char - copy_funcs(%r8), %r9
	leaq	write_char_flush - copy_funcs(%r8), %r10
	leaq	copy_funcs_end - copy_funcs(%r8), %r11
	pushq	%r8
	call_code:
	call	*%r11
	popq	%r8
	addq	$0x8000, %rsp
	movq	$11, %rax
	movq	%r8, %rdi
	movq	-0x10(%rbp), %rsi
	syscall
	movq	-0x8(%rbp), %r8
	movq	-0x10(%rbp), %r9
	movq	-0x18(%rbp), %r10
	movq	%rbp, %rsp
	popq	%rbx
	popq	%rbp
	ret
.text
.global brainfuck
brainfuck:
	pushq	%rbx
	pushq	%r12
	pushq	%r13
	pushq	%r14
	pushq	%r15
	pushq	%rbp
	movq	%rsp, %rbp
	subq	$0x18, %rsp
	pushq	%rdi
		call	stinit
		movq	%r8, -0x8(%rbp)
		movq	%r9, -0x10(%rbp)
		movq	%r10, -0x18(%rbp)
		call	stinit
	popq	%rdi
	movq	$0, %r15
	call	base_parser
	cmpq	$0, %r15
	jne		brainfuck_end	
	call	stdel
	movq	-0x8(%rbp), %r8
	movq	-0x10(%rbp), %r9
	movq	-0x18(%rbp), %r10
	call	runcode
	call	stdel
	brainfuck_end:
	movq	%rbp, %rsp
	popq	%rbp
	popq	%r15
	popq	%r14
	popq	%r13
	popq	%r12
	popq	%rbx
	ret
