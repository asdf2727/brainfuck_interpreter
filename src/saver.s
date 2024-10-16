# %rax - temp (read/write syscall)
# %rbx - tape pointer
# %rcx - temp (mult const)
# %rdx - temp (read/write count)
# %rsi - temp (read/write ptr)
# %rdi - temp (read/write fd)
# %rsp - used
# %rbp - used

.text

.include "lib/inc/stk.s"

write_add:
	leaq	-0x30(%rbp), %rdx
	cmpq	%rdx, %rsp
	jge		write_add_end
	write_add_loop:
		movb	(%rdx), %cl
		movq	0x8(%rdx), %rax
		#	addb	VAL, OFFSET(%rbx)
		addq	$7, %r9
		call	stinc
		movw	$0x8380, -7(%r8, %r9)
		movl	%eax, -5(%r8, %r9)
		movb	%cl, -1(%r8, %r9)
		write_add_loop_end:
		subq	$0x10, %rdx
		cmpq	%rdx, %rsp
		jl		write_add_loop
	write_add_end:
	popq	%rax
	popq	%rdx
	leaq	-0x20(%rbp), %rsp
	pushq	%rdx
	jmp		*%rax

.global save_add
save_add:
	leaq	-0x20(%rbp), %rdx
	movq	%rdx, %rsi

	cmpq	%rdx, %rsp
	jge		save_add_write
	save_add_loop:
		cmpb	$0, -0x10(%rdx)
		je		save_add_loop_end
			movq	-0x10(%rdx), %r11
			movq	%r11, -0x10(%rsi)
			movq	-0x8(%rdx), %r11
			movq	%r11, -0x8(%rsi)
			subq	$0x10, %rsi
		save_add_loop_end:
		subq	$0x10, %rdx
		cmpq	%rdx, %rsp
		jl		save_add_loop

	save_add_write:
	movq	%rsi, %rsp
	call	write_add
	ret

.global save_add_move
save_add_move:
	pushq	$0
	movq	-0x10(%rbp), %rax
	leaq	-0x30(%rbp), %rdx
	leaq	0x10(%rdx), %rsi

	cmpq	%rdx, %rsp
	jge		save_add_move_write
	save_add_move_loop:
		cmpb	$0, (%rdx)
		je		save_add_move_loop_end
		cmpb	%al, 0x8(%rdx)
		je		save_add_move_loop_found
			movq	(%rdx), %r11
			movq	%r11, -0x10(%rsi)
			movq	0x8(%rdx), %r11
			movq	%r11, -0x8(%rsi)
			subq	$0x10, %rsi
			jmp		save_add_move_loop_end
		save_add_move_loop_found:
			movq	(%rdx), %r11
			addq	%r11, (%rsp)
		save_add_move_loop_end:
		subq	$0x10, %rdx
		cmpq	%rdx, %rsp
		jl		save_add_move_loop

	save_add_move_write:
	popq	%r11
	popq	%rax
	movq	%rsi, %rsp
	pushq	%rax
	call	write_add

	movq	-0x10(%rbp), %rax
	cmpq	$0, %rax
	je		save_add_move_last
		movq	$0, -0x10(%rbp)
		# 	addq	VAL, %rbx
		addq	$7, %r9
		call	stinc
		movb	$0x48, -7(%r8, %r9)
		movw	$0xC381, -6(%r8, %r9)
		movl	%eax, -4(%r8, %r9)
	save_add_move_last:
	# Need this even if VAL is 0!
	# 	addq	VAL, (%rbx)
	addq	$3, %r9
	call	stinc
	movw	$0x0380, -3(%r8, %r9)
	movb	%r11b, -1(%r8, %r9)
	ret

# %cl - value to multiply
# %rax - lookup table pointer
# %rsi - if answer was negated
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
	#	imull	MULT, %ecx, %ecx
	addq	$3, %r9
	call	stinc
	movw	$0xC96B, -3(%r8, %r9)
	movb	%cl, -1(%r8, %r9)
save_mult_1:
	shrq	$8, %rcx
	cmpb	$0, %cl
	je		save_mult_no_shift
		#	sarb	SHIFT, %cl
		addq	$3, %r9
		call	stinc
		movw	$0xF9C0, -3(%r8, %r9)
		movb	%cl, -1(%r8, %r9)
	save_mult_no_shift:
	ret

save_mult_0:
	#	TODO	add error detection
	#	xorl	%ecx, %ecx
	addq	$2, %r9
	call	stinc
	movw	$0xC933, -2(%r8, %r9)
	ret

.global save_mult
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
	#	movl	(%rbx), %ecx
	stpushw	$0x0B8B
	movq	$1, %r11
	
	#	imull	MULT, %ecx, %ecx
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
	#	imull	VAL, %ecx, %edx
	addq	$3, %r9
	call	stinc
	movw	$0xD16B, -3(%r8, %r9)
	movb	%cl, -1(%r8, %r9)
	#	addb	%dl, OFFSET(%rbx)
	addq	$6, %r9
	call	stinc
	movw	$0x9300, -6(%r8, %r9)
	jmp		save_add_mult_add_end

save_add_mult_1:
	#	addb	%cl, OFFSET(%rbx)
	addq	$6, %r9
	call	stinc
	movw	$0x8B00, -6(%r8, %r9)

save_add_mult_add_end:
	movq	(%rdx), %rax
	movl	%eax, -4(%r8, %r9)
	xorq	%r11, %rsi
	imulq	$0x28, %rsi, %rsi
	addl	%esi, -6(%r8, %r9)	# turn into subb if necessary
	ret

save_add_mult_0:
	#	movb	$0, OFFSET(%rbx)
	addq	$3, %r9
	call	stinc
	movl	$0x0083C6, -3(%r8, %r9)
	ret

.global save_mult_add
save_mult_add:
	leaq	-0x28(%rbp), %rdx
	save_mult_add_loop:
		cmpq	$0, (%rdx)
		je		save_mult_add_loop_end

			#	imull	VAL, %ecx, (%rbx)
			movb	-0x8(%rdx), %cl
			movq	$save_mult_add_table, %rax
			call	mult_optimise

		save_mult_add_loop_end:
		subq	$0x10, %rdx
		cmpq	%rdx, %rsp
		jl		save_mult_add_loop
	save_mult_add_end:

	#	movb	$0, (%rbx)
	addq	$3, %r9
	call	stinc
	movl	$0x0003C6, -3(%r8, %r9)

	movq	(%rsp), %rax
	jmp		*%rax

.global save_open
save_open:
	#	cmpb	$0, (%rbx)
	#	je		somewhere
	addq	$9, %r9
	call	stinc
	movl	$0x0F003B80, -9(%r8, %r9)
	movb	$0x84, -5(%r8, %r9)
	ret

.global save_close
save_close:
	#	cmpb	$0, (%rbx)
	#	jne		somewhere
	addq	$9, %r9
	call	stinc
	movl	$0x0F003B80, -9(%r8, %r9)
	movb	$0x85, -5(%r8, %r9)
	ret

.global save_write
save_write:
	movq	-0x10(%rbp), %rax
	#	xorl	%eax, %eax
	#	movb	$1, %al
	#	movl	%eax, %edx
	#	movl	%eax, %edi
	#	leal	OFFSET(%rbx), %esi
	#	syscall
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

.global save_read
save_read:
	movq	-0x10(%rbp), %rax
	#	xorl	%eax, %eax
	#	xorl	%edi, %edi
	#	xorl	%edx, %edx
	#	movl	$1, %edx
	#	leab	OFFSET(%rbx), %esi
	#	syscall
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

.global save_ret
save_ret:
	stpushb	$0xC3	# near ret
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
