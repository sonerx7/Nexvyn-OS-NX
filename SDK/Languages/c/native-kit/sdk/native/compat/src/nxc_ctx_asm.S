/* Nexvyn compat layer - AArch64 context switch (AAPCS64). Layout: include/ucontext.h (offsets asserted in nxc_ctx.c). */
    .set MCTX, 48            /* offsetof(ucontext_t, uc_mcontext) */

    .text

/* Saves the callee-saved state into the mcontext at [x17]. Clobbers x2, x3. Resumes at lr with x0 = 0. */
    .macro SAVE_CTX
    str xzr, [x17, #0]       /* fault_address = 0 */
    stp xzr, xzr, [x17, #8]  /* regs[0..1] */
    stp xzr, xzr, [x17, #24] /* regs[2..3] */
    stp xzr, xzr, [x17, #40] /* regs[4..5] */
    stp xzr, xzr, [x17, #56] /* regs[6..7] */
    stp x19, x20, [x17, #160]
    stp x21, x22, [x17, #176]
    stp x23, x24, [x17, #192]
    stp x25, x26, [x17, #208]
    stp x27, x28, [x17, #224]
    stp x29, x30, [x17, #240]
    mov x2, sp
    str x2, [x17, #256]      /* sp */
    str xzr, [x17, #264]     /* pc = 0 (continue at lr) */
    stp xzr, xzr, [x17, #272] /* pstate = 0, esr = 0 */
    stp d8, d9, [x17, #288]
    stp d10, d11, [x17, #304]
    stp d12, d13, [x17, #320]
    stp d14, d15, [x17, #336]
    mrs x2, fpcr
    mrs x3, fpsr
    stp x2, x3, [x17, #352]
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
    ldp x19, x20, [x17, #160]
    ldp x21, x22, [x17, #176]
    ldp x23, x24, [x17, #192]
    ldp x25, x26, [x17, #208]
    ldp x27, x28, [x17, #224]
    ldp x29, x30, [x17, #240]
    ldr x2, [x17, #256]
    mov sp, x2
    ldp d8, d9, [x17, #288]
    ldp d10, d11, [x17, #304]
    ldp d12, d13, [x17, #320]
    ldp d14, d15, [x17, #336]
    ldp x2, x3, [x17, #352]
    msr fpcr, x2
    msr fpsr, x3
    ldr x16, [x17, #264]
    ldp x2, x3, [x17, #24]
    ldp x4, x5, [x17, #40]
    ldp x6, x7, [x17, #56]
    ldp x0, x1, [x17, #8]
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
