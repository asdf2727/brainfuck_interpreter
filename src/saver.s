# %rax - temp (read/write syscall)
# %rbx - tape pointer
# %rcx - temp (mult const)
# %rdx - temp (read/write count)
# %rsi - temp (read/write ptr)
# %rdi - temp (read/write fd)
# %rsp - used
# %rbp - used

.data

TP_add:	.quad	0

.text

.include "lib/inc/stk.s"

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
	call	sanitise_add
	stswap
	call	write_add

	movb	TP_add, %cl
	cmpb	$0, %cl
	je		save_add_skip_last
		movq	-0x10(%rbp), %rax
		#	addb	VAL, OFFSET(%rbx)
		addq	$7, %r9
		call	stinc
		movw	$0x8380, -7(%r8, %r9)
		movl	%eax, -5(%r8, %r9)
		movb	%cl, -1(%r8, %r9)
	save_add_skip_last:

	stswap
	ret

.global save_add_move
save_add_move:
	call	sanitise_add
	stswap
	call	write_add

	movq	-0x10(%rbp), %rax
	cmpq	$0, %rax
	je		save_add_move_skip_move
		movq	$0, -0x10(%rbp)
		# 	addq	VAL, %rbx
		addq	$7, %r9
		call	stinc
		movl	$0x00C38148, -7(%r8, %r9)
		movl	%eax, -4(%r8, %r9)
	save_add_move_skip_move:

	movb	TP_add, %cl
	cmpb	$0, %cl
	je		save_add_move_skip_last
		# 	addq	VAL, (%rbx)
		addq	$3, %r9
		call	stinc
		movw	$0x0380, -3(%r8, %r9)
		movb	%cl, -1(%r8, %r9)
	save_add_move_skip_last:

	stswap
	ret

# %cl - value to multiply
# %rax - lookup table pointer
# %rbx - if answer was negated
mult_optimise:
	negb	%cl
	pushq	$1

	mult_optimise_tests:
		# 0 test
		addq	$8, %rax
		cmpb	$0, %cl
		je		mult_optimise_done
		# 1 test
		addq	$8, %rax
		cmpb	$1, %cl
		je		mult_optimise_done
		# pow2 test
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

#	TODO	add error detection
write_mult:
	movb	TP_add, %cl
	movw	mult_table(, %rcx, 2), %cx
	
	movq	$1, %r12

	movq	$write_mult_table, %rax
	jmp		mult_optimise
	
	write_mult_default:
	#	imull	MULT, (%ebx), %ecx
	addq	$3, %r9
	call	stinc
	movw	$0x0B6B, -3(%r8, %r9)
	movb	%cl, -1(%r8, %r9)
	jmp		write_mult_shift
	
	write_mult_pow2:
	bsfq	%rcx, %rdx
	subb	%dl, %ch
	write_mult_1:
	#	movl	(%rbx), %ecx
	stpushw	$0x0B8B
	write_mult_shift:
	shrq	$8, %rcx
	cmpb	$0, %cl
	je		write_mult_no_shift
		#	sarb	SHIFT, %cl
		addq	$3, %r9
		call	stinc
		movw	$0xF9C0, -3(%r8, %r9)
		movb	%cl, -1(%r8, %r9)
	write_mult_no_shift:
	jmp		write_mult_end

	write_mult_0:
	#	xorl	%ecx, %ecx
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

.global save_mult
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
			#	imull	VAL, %ecx, %edx
			addq	$3, %r9
			call	stinc
			movw	$0xD16B, -3(%r8, %r9)
			movb	%cl, -1(%r8, %r9)
			jmp		save_mult_write_add
			save_mult_pow2:
			bsfq	%rcx, %rax
			#	movb	%cl, %dl
			#	salq	logVAL, %dl
			addq	$5, %r9
			call	stinc
			movl	$0xE2C0CA88, -5(%r8, %r9)
			movb	%al, -1(%r8, %r9)

			save_mult_write_add:
			#	addb	%dl, OFFSET(%rbx)
			addq	$6, %r9
			call	stinc
			movw	$0x9300, -6(%r8, %r9)
			jmp		save_mult_write_end
			save_mult_1:
			#	addb	%cl, OFFSET(%rbx)
			addq	$6, %r9
			call	stinc
			movw	$0x8B00, -6(%r8, %r9)

			save_mult_write_end:
			movq	(%rsi), %rax
			movl	%eax, -4(%r8, %r9)
			xorq	%r12, %rbx
			imulq	$0x28, %rbx, %rbx
			addl	%ebx, -6(%r8, %r9)	# turn into subb if necessary
			save_mult_0:

		save_mult_loop_end:
		addq	$0x10, %rsi
		cmpq	%rdx, %rsi
		jne		save_mult_loop
	save_mult_end:
	movq	$0, 0x18(%r11)
	#	movb	$0, (%rbx)
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
		# 	cmpb	$0x00, (%rbx)
		addq	$3, %r9
		call	stinc
		movw	$0x3B80, -3(%r8, %r9)
		movb	$0x00, -1(%r8, %r9) 
	save_cmp_skip:
	ret

.global save_open
save_open:
	stswap
	call	save_cmp
	#	je		somewhere
	addq	$6, %r9
	call	stinc
	movl	$0x840F, -6(%r8, %r9)
	movq	%r9, -0x8(%rbp)
	stswap
	ret

.global save_close
save_close:
	stswap
	call	save_cmp
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
