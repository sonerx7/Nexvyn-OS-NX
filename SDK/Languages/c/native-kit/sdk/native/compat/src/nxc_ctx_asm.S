/* Nexvyn compat layer - AArch64 context switch (AAPCS64). Layout: include/ucontext.h (offsets asserted in nxc_ctx.c). */
    .set MCTX, 48            /* offsetof(ucontext_t, uc_mcontext) */

    .text

/* Saves the callee-saved state into the mcontext at [x17]. Clobbers x2, x3. Resumes at lr with x0 = 0. */
    .macro SAVE_CTX
    stp xzr, xzr, [x17, #0]
    stp xzr, xzr, [x17, #16]
    stp xzr, xzr, [x17, #32]
    stp xzr, xzr, [x17, #48]
    stp x19, x20, [x17, #64]
    stp x21, x22, [x17, #80]
    stp x23, x24, [x17, #96]
    stp x25, x26, [x17, #112]
    stp x27, x28, [x17, #128]
    stp x29, x30, [x17, #144]
    mov x2, sp
    str x2, [x17, #160]
    str xzr, [x17, #168]
    stp d8, d9, [x17, #176]
    stp d10, d11, [x17, #192]
    stp d12, d13, [x17, #208]
    stp d14, d15, [x17, #224]
    mrs x2, fpcr
    mrs x3, fpsr
    stp x2, x3, [x17, #240]
    .endm

    .global getcontext
    .type getcontext, %function
    .p2align 4
getcontext:
    add x17, x0, #MCTX
    SAVE_CTX
    mov x0, #0
    ret
    .size getcontext, .-getcontext

    .global setcontext
    .type setcontext, %function
    .p2align 4
setcontext:
    add x17, x0, #MCTX
    ldp x19, x20, [x17, #64]
    ldp x21, x22, [x17, #80]
    ldp x23, x24, [x17, #96]
    ldp x25, x26, [x17, #112]
    ldp x27, x28, [x17, #128]
    ldp x29, x30, [x17, #144]
    ldr x2, [x17, #160]
    mov sp, x2
    ldp d8, d9, [x17, #176]
    ldp d10, d11, [x17, #192]
    ldp d12, d13, [x17, #208]
    ldp d14, d15, [x17, #224]
    ldp x2, x3, [x17, #240]
    msr fpcr, x2
    msr fpsr, x3
    ldr x16, [x17, #168]
    ldp x2, x3, [x17, #16]
    ldp x4, x5, [x17, #32]
    ldp x6, x7, [x17, #48]
    ldp x0, x1, [x17, #0]
    cbz x16, 1f
    br x16
1:
    ret
    .size setcontext, .-setcontext

    .global swapcontext
    .type swapcontext, %function
    .p2align 4
swapcontext:
    add x17, x0, #MCTX
    SAVE_CTX
    mov x0, x1
    b setcontext
    .size swapcontext, .-swapcontext

/* First code of a made context: x19 = function, x20 = successor context, x0-x7 = arguments. */
    .global nxc_ctx_entry
    .type nxc_ctx_entry, %function
    .p2align 4
nxc_ctx_entry:
    blr x19
    mov x0, x20
    cbz x0, 2f
    bl setcontext
2:
    mov x0, #0
    bl exit
    brk #0
    .size nxc_ctx_entry, .-nxc_ctx_entry
