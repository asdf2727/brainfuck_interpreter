.data

debug_out: .asciz "DEBUG: %ld\n"

.text

.include "lib/inc/utils.s"

# stack safe scanf
.global	scanf_safe
scanf_safe:
	allign_stack $0xf
	xorq	%rax, %rax
	call	scanf
	popq	%rsp # deallign stack
	ret

# stack safe printf
.global	printf_safe
printf_safe:
	allign_stack $0x0f
	xorq	%rax, %rax
	call	printf
	popq	%rsp # deallign stack
	ret
