# This is an automated export version of the project, not meant for editing or reading.
# ## TODO

# - [ ] use addb with 0x0(%rbx) before a jump if you can to avoid using a cmpb
# - [x] also set 0x0(%rbx) to $0 when multiplying to avoid wasted instructions
# - [x] bring back multiplier to optimise loops
# eventually only optimise loops with +- 1 in checked pointer to reduce
# - [x] remove imul operations whenever possible
# - [x] prepare syscall registers IN ADVANCE to avoid wasting instructions on mov $1, %reg
# - [x] use offset for write/read instructions
# - [ ] use buffering for output to avoid using syscalls too many times
# - [ ] 1 syscall for stdin if you can (don't count on it)
# - [ ] use registers for variables where possible

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
.macro stsave DST
	movq	%r8, (\DST)
	movq	%r9, 0x8(\DST)
	movq	%r10, 0x10(\DST)
.endm
.macro stload SRC
	movq	(\SRC), %r8
	movq	0x8(\SRC), %r9
	movq	0x10(\SRC), %r10
.endm
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
	movq	%r15, %rsp
	popq	%rbp
	ret
base_parser:
	movq	%rbp, %r15	
	pushq	%rbp
	movq	%rsp, %rbp
	movq	$0, %rcx	
	pushq	$0						
	pushq	$0						
	pushq	$base_parser_loop_end	
	pushq	$1						
	pushq	$0
	pushq	$0
	jmp		parser_loop
	base_parser_loop_end:
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
	movq	%r15, %rsp
	popq	%rbp
	ret
rec_parser:
	pushq	%rbp
	movq	%rsp, %rbp
	call	save_open
	pushq	%r9						
	pushq	$0						
	pushq	$rec_parser_loop_end	
	pushq	$0						
	pushq	$0
	pushq	$0
	jmp		parser_loop
	rec_parser_loop_end:
	cmpb	$93, -0x1(%rdi)
	jne		no_closed_par
	movq	-0x10(%rbp), %rax
	orq		-0x20(%rbp), %rax
	cmpq	$0, %rax
	jne		rec_parser_no_optimise
rec_parser_optimise:
	call	save_mult
	call	save_mult_add
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
	movq	-0x8(%rbp), %rax
	movl	%r9d, -0x4(%r8, %rax)
	subl	%eax, -0x4(%r8, %rax)
	movl	%eax, -0x4(%r8, %r9)
	subl	%r9d, -0x4(%r8, %r9)
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
.text
save_add:
	leaq	-0x28(%rbp), %rdx
	save_add_loop:
		cmpb	$0, -0x8(%rdx)
		je		save_add_loop_end
			movq	(%rdx), %rax
			movb	-0x8(%rdx), %cl
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
		addq	$7, %r9
		call	stinc
		movb	$0x48, -7(%r8, %r9)
		movw	$0xC381, -6(%r8, %r9)
		movl	%eax, -4(%r8, %r9)
	save_move_end:
	ret
mult_optimise:
	negb	%cl
	movq	$1, %rsi
	mult_optimise_tests:
		addq	$8, %rax
		cmpb	$0, %cl
		je		mult_optimise_done
		addq	$8, %rax
		cmpb	$1, %cl
		je		mult_optimise_done
	subq	$16, %rax
	cmpq	$0, %rsi
	je		mult_optimise_done
	negb	%cl
	movq	$0, %rsi
	jmp		mult_optimise_tests
	mult_optimise_done:
	jmp		*(%rax)
.data
save_mult_table:
.quad	save_mult_default
.quad	save_mult_0
.quad	save_mult_1
.text
save_mult_default:
	addq	$3, %r9
	call	stinc
	movw	$0xC96B, -3(%r8, %r9)
	movb	%cl, -1(%r8, %r9)
save_mult_1:
	shrq	$8, %rcx
	cmpb	$0, %cl
	je		save_mult_no_shift
		addq	$3, %r9
		call	stinc
		movw	$0xF9C0, -3(%r8, %r9)
		movb	%cl, -1(%r8, %r9)
	save_mult_no_shift:
	ret
save_mult_0:
	addq	$2, %r9
	call	stinc
	movw	$0xC933, -2(%r8, %r9)
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
	stpushw	$0x0B8B
	movq	$1, %r11
	movq	$save_mult_table, %rax
	call	mult_optimise
	xorq	%rsi, %r11
	ret
.data
save_mult_add_table:
.quad	save_add_mult_default
.quad	save_add_mult_0
.quad	save_add_mult_1
.text
save_add_mult_default:
	addq	$3, %r9
	call	stinc
	movw	$0xD16B, -3(%r8, %r9)
	movb	%cl, -1(%r8, %r9)
	addq	$6, %r9
	call	stinc
	movw	$0x9300, -6(%r8, %r9)
	jmp		save_add_mult_add_end
save_add_mult_1:
	addq	$6, %r9
	call	stinc
	movw	$0x8B00, -6(%r8, %r9)
save_add_mult_add_end:
	movq	(%rdx), %rax
	movl	%eax, -4(%r8, %r9)
	xorq	%r11, %rsi
	imulq	$0x28, %rsi, %rsi
	addl	%esi, -6(%r8, %r9)	
	ret
save_add_mult_0:
	addq	$3, %r9
	call	stinc
	movl	$0x0083C6, -3(%r8, %r9)
	ret
save_mult_add:
	leaq	-0x28(%rbp), %rdx
	save_mult_add_loop:
		cmpq	$0, (%rdx)
		je		save_mult_add_loop_end
			movb	-0x8(%rdx), %cl
			movq	$save_mult_add_table, %rax
			call	mult_optimise
		save_mult_add_loop_end:
		subq	$0x10, %rdx
		cmpq	%rdx, %rsp
		jl		save_mult_add_loop
	save_mult_add_end:
	addq	$3, %r9
	call	stinc
	movl	$0x0003C6, -3(%r8, %r9)
	movq	(%rsp), %rax
	jmp		*%rax
save_open:
	addq	$9, %r9
	call	stinc
	movl	$0x0F003B80, -9(%r8, %r9)
	movb	$0x84, -5(%r8, %r9)
	ret
save_close:
	addq	$9, %r9
	call	stinc
	movl	$0x0F003B80, -9(%r8, %r9)
	movb	$0x85, -5(%r8, %r9)
	ret
save_write:
	movq	-0x10(%rbp), %rax
	addq	$12, %r9
	call	stinc
	movl	$0xC0C6C031, -12(%r8, %r9)
	movl	$0x89C28901, -8(%r8, %r9)
	movl	$0xB38D48C7, -4(%r8, %r9)
	addq	$6, %r9
	call	stinc
	movl	%eax, -6(%r8, %r9)
	movw	$0x050F, -2(%r8, %r9)
	ret
save_read:
	movq	-0x10(%rbp), %rax
	addq	$12, %r9
	call	stinc
	movl	$0xFF31C031, -12(%r8, %r9)
	movl	$0xC2C6D231, -8(%r8, %r9)
	movl	$0xB38D4801, -4(%r8, %r9)
	addq	$6, %r9
	call	stinc
	movl	%eax, -6(%r8, %r9)
	movw	$0x050F, -2(%r8, %r9)
	ret
save_ret:
	stpushb	$0xC3	
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
.text
runcode:
	pushq	%rbp
	pushq	%rbx
	movq	%rsp, %rbp
	subq	$0x18, %rsp
	stsave	%rsp
	movq	$9, %rax
	movq	$0, %rdi
	movq	-0x10(%rbp), %rsi
	movq	$3, %rdx
	movq	$33, %r10
	movq	$-1, %r8
	movq	$0, %r9
	syscall
	movq	%rax, %r8
	movq	-0x10(%rbp), %rcx
	movq	-0x18(%rbp), %rsi
	movq	%rax, %rdi
	rep movsb
	movq	%rax, %rdi
	movq	$10, %rax
	movq	-0x10(%rbp), %rsi
	movq	$5, %rdx
	syscall
	subq	$0x8000, %rsp
	movq	$0x1000, %rcx
	movq	%rsp, %rdi
	movq	$0, %rax
	rep stosq
	movq	$1, %rdi
	movq	$1, %rdx
	movq	$0, %rax
	movq	%rsp, %rbx
	pushq	%r8
	call_code:
	call	*%r8
	popq	%r8
	addq	$0x8000, %rsp
	movq	$11, %rax
	movq	%r8, %rdi
	movq	-0x10(%rbp), %rsi
	syscall
	stload	%rsp
	addq	$0x18, %rsp
	movq	%rbp, %rsp
	popq	%rbx
	popq	%rbp
	ret
.text
.global brainfuck
brainfuck:
	pushq	%rbp
	pushq	%rbx
	pushq	%r12
	pushq	%r13
	pushq	%r14
	pushq	%r15
	movq	%rsp, %rbp
	pushq	%rdi
	call	stinit
	movq	$0x10000, %rdi
	call	stresize
	movq	$0, %r9
	popq	%rdi
	call	base_parser
	cmpb	$0, -0x1(%rdi)
	jne		brainfuck_end	
	call	runcode
	call	stdel
	brainfuck_end:
	movq %rbp, %rsp
	popq	%r15
	popq	%r14
	popq	%r13
	popq	%r12
	popq	%rbx
	popq %rbp
	ret
