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

.macro stswap
	xchgq	%r8, 0x20(%r11)
	xchgq	%r9, 0x18(%r11)
	xchgq	%r10, 0x10(%r11)
.endm

write_add:
	movq	0x20(%r11), %rsi
	movq	0x18(%r11), %rdx
	cmpq	$0, %rdx
	je		write_add_end
	addq	%rsi, %rdx
	write_add_loop:
		movq	(%rsi), %rax
		movb	0x8(%rsi), %cl
		#	addb	VAL, OFFSET(%rbx)
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

.global save_add
save_add:
	movq	$0, %rdx
	movq	$0, %rsi

	cmpq	%rsi, %r9
	je		save_add_write
	save_add_loop:
		cmpb	$0, 0x8(%r8, %rsi)
		je		save_add_loop_end
			movq	(%r8, %rsi), %rax
			movq	%rax, (%r8, %rdx)
			movq	0x8(%r8, %rsi), %rax
			movq	%rax, 0x8(%r8, %rdx)
			addq	$0x10, %rdx
		save_add_loop_end:
		addq	$0x10, %rsi
		cmpq	%rsi, %r9
		jne		save_add_loop

	save_add_write:
	movq	%rdx, %r9
	stswap
	call	write_add
	stswap
	ret

.global save_add_move
save_add_move:
	pushq	$0
	movq	-0x10(%rbp), %rcx
	movq	$0, %rdx
	movq	$0, %rsi
	cmpq	%rsi, %r9
	je		save_add_move_write
	save_add_move_loop:
		cmpb	$0, 0x8(%r8, %rsi)
		je		save_add_move_loop_end
			cmpq	%rcx, (%r8, %rsi)
			jne		save_add_move_other
				movq	0x8(%r8, %rsi), %rax
				movq	%rax, (%rsp)
				jmp		save_add_move_loop_end
			save_add_move_other:
				movq	(%r8, %rsi), %rax
				movq	%rax, (%r8, %rdx)
				movq	0x8(%r8, %rsi), %rax
				movq	%rax, 0x8(%r8, %rdx)
				addq	$0x10, %rdx
		save_add_move_loop_end:
		addq	$0x10, %rsi
		cmpq	%rsi, %r9
		jne		save_add_move_loop

	save_add_move_write:
	movq	$0, %rcx
	movq	%rdx, %r9
	stswap
	call	write_add

	movq	-0x10(%rbp), %rax
	cmpq	$0, %rax
	je		save_add_move_last
		movq	$0, -0x10(%rbp)
		# 	addq	VAL, %rbx
		addq	$7, %r9
		call	stinc
		movl	$0x00C38148, -7(%r8, %r9)
		movl	%eax, -4(%r8, %r9)
	
	save_add_move_last:
	popq	%rax
	cmpq	$0, %rax
	je		save_add_move_last_cmp
	save_add_move_last_add:
		# 	addq	VAL, (%rbx)
		addq	$3, %r9
		call	stinc
		movw	$0x0380, -3(%r8, %r9)
		movb	%al, -1(%r8, %r9) 
		stswap
		ret
	save_add_move_last_cmp:
		# 	cmpb	$0x00, (%rbx)
		addq	$3, %r9
		call	stinc
		movw	$0x3B80, -3(%r8, %r9)
		movb	$0x00, -1(%r8, %r9) 
		stswap
		ret

# %cl - value to multiply
# %rax - lookup table pointer
# %rbx - if answer was negated
mult_optimise:
	negb	%cl
	movq	$1, %rbx

	mult_optimise_tests:
		addq	$8, %rax
		cmpb	$0, %cl
		je		mult_optimise_done
		addq	$8, %rax
		cmpb	$1, %cl
		je		mult_optimise_done

	subq	$16, %rax
	cmpq	$0, %rbx
	je		mult_optimise_done
	negb	%cl
	movq	$0, %rbx
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
	movq	$0, %rsi
	cmpq	%rsi, %r9
	je		save_mult_loop_end
	save_mult_loop:
		cmpb	$0, (%r8, %rsi)
		jne		save_mult_loop_skip
			addq	0x8(%r8, %rsi), %rax
		save_mult_loop_skip:
		addq	$0x10, %rsi
		cmpq	%rsi, %r9
		jne		save_mult_loop
	save_mult_loop_end:
	andq	$0xff, %rax
	movw	mult_table(, %rax, 2), %cx
	
	stswap
	#	movl	(%rbx), %ecx
	stpushw	$0x0B8B
	movq	$1, %r12
	
	#	imull	MULT, %ecx, %ecx
	movq	$save_mult_table, %rax
	call	mult_optimise
	xorq	%rbx, %r12

	stswap
	ret

.data

save_mult_add_table:
.quad	save_mult_add_default
.quad	save_mult_add_0
.quad	save_mult_add_1

.text

save_mult_add_default:
	#	imull	VAL, %ecx, %edx
	addq	$3, %r9
	call	stinc
	movw	$0xD16B, -3(%r8, %r9)
	movb	%cl, -1(%r8, %r9)
	#	addb	%dl, OFFSET(%rbx)
	addq	$6, %r9
	call	stinc
	movw	$0x9300, -6(%r8, %r9)
	jmp		save_mult_add_add_end

save_mult_add_1:
	#	addb	%cl, OFFSET(%rbx)
	addq	$6, %r9
	call	stinc
	movw	$0x8B00, -6(%r8, %r9)

save_mult_add_add_end:
	movq	(%rsi), %rax
	movl	%eax, -4(%r8, %r9)
	xorq	%r12, %rbx
	imulq	$0x28, %rbx, %rbx
	addl	%ebx, -6(%r8, %r9)	# turn into subb if necessary
	ret

save_mult_add_0:
	ret

.global save_mult_add
save_mult_add:
	stswap
	movq	0x20(%r11), %rsi
	movq	0x18(%r11), %rdx
	cmpq	$0, %rdx
	je		write_add_end
	addq	%rsi, %rdx
	save_mult_add_loop:
		cmpq	$0, 0x8(%rsi)
		je		save_mult_add_loop_end
		cmpq	$0, (%rsi)
		je		save_mult_add_loop_end

			#	imull	VAL, %ecx, OFFSET(%rbx)
			movb	0x8(%rsi), %cl
			movq	$save_mult_add_table, %rax
			call	mult_optimise

		save_mult_add_loop_end:
		addq	$0x10, %rsi
		cmpq	%rdx, %rsi
		jne		save_mult_add_loop
	save_mult_add_end:
	movq	$0, 0x18(%r11)
	#	movb	$0, (%rbx)
	addq	$3, %r9
	call	stinc
	movw	$0x03C6, -3(%r8, %r9)
	movb	$0x00, -1(%r8, %r9)
	stswap
	ret

.global save_open
save_open:
	stswap
	#	je		somewhere
	addq	$6, %r9
	call	stinc
	movl	$0x840F, -6(%r8, %r9)
	stswap
	ret

.global save_close
save_close:
	stswap
	#	jne		somewhere
	addq	$6, %r9
	call	stinc
	movl	$0x850F, -6(%r8, %r9)
	stswap
	ret

.global save_write
save_write:
	stswap
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
	stswap
	ret

.global save_read
save_read:
	stswap
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
	stswap
	ret

.global save_ret
save_ret:
	stswap
	stpushb	$0xC3	# near ret
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
