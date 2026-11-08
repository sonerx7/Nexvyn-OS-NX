/* Nexvyn compat layer - makecontext() and the nxc_coro_* coroutine API (the switch itself is nxc_ctx_asm.S). */
#include <errno.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <ucontext.h>

#include "nexvyn/compat.h"
#include "nxc_internal.h"

_Static_assert(offsetof(ucontext_t, uc_mcontext) == 48, "nxc_ctx_asm.S assumes uc_mcontext at offset 48");
_Static_assert(sizeof(mcontext_t) == 256, "nxc_ctx_asm.S assumes a 256 byte mcontext");

extern void nxc_ctx_entry(void);

void makecontext(ucontext_t* ucp, void (*func)(void), int argc, ...) {
    if (!ucp || !func || !ucp->uc_stack.ss_sp || ucp->uc_stack.ss_size < 256) {
        /* A library never kills the process: log and leave the context untouched (POSIX has no error return here). */
        nxc_log("makecontext: needs uc_stack.ss_sp and a stack of at least 256 bytes; the context was not set up");
        return;
    }
    if (argc < 0) argc = 0;
    if (argc > 8) {
        nxc_log("makecontext: at most 8 arguments are supported, got %d", argc);
        argc = 8;
    }
    mcontext_t* m = &ucp->uc_mcontext;
    memset(m, 0, sizeof *m);
    uintptr_t top = ((uintptr_t)ucp->uc_stack.ss_sp + ucp->uc_stack.ss_size) & ~(uintptr_t)15;
    m->sp = top;
    m->x19_28[0] = (uint64_t)(uintptr_t)func;
    m->x19_28[1] = (uint64_t)(uintptr_t)ucp->uc_link;
    m->pc = (uint64_t)(uintptr_t)nxc_ctx_entry;
    va_list ap;
    va_start(ap, argc);
    for (int i = 0; i < argc; i++) m->x[i] = (uint32_t)va_arg(ap, int);
    va_end(ap);
}

/* ---- coroutines ---- */

#define STACK_FILL 0xA5
#define GUARD_BYTES 128
#define MIN_STACK (8u * 1024u)

struct nxc_coro {
    ucontext_t ctx;
    ucontext_t caller;
    nxc_coro_fn fn;
    void* arg;
    uint8_t* stack;
    size_t stack_size;
    nxc_coro* prev;  /* the coroutine that resumed this one (NULL = thread stack) */
    int state;       /* 0 suspended, 1 running, 2 finished */
    int overflow;
};

#if NXC_WINDOWED
typedef struct {
    nxc_coro* cur;
} ctx_tls;
static nxc_tlskey g_ctx_key = {0, 0, free};
static ctx_tls g_ctx_fallback; /* only when memory is gone */
static ctx_tls* ctx_tl(void) {
    ctx_tls* t = (ctx_tls*)nxc__tls_get(&g_ctx_key);
    if (!t) {
        t = (ctx_tls*)calloc(1, sizeof *t);
        if (!t) return &g_ctx_fallback;
        nxc__tls_set(&g_ctx_key, t);
    }
    return t;
}
#define t_current (ctx_tl()->cur)
#else
static __thread nxc_coro* t_current;
#endif

static void coro_main(unsigned lo, unsigned hi) {
    nxc_coro* c = (nxc_coro*)(uintptr_t)(((uint64_t)hi << 32) | lo);
    c->fn(c->arg);
    c->state = 2;
}

nxc_coro* nxc_coro_create(nxc_coro_fn fn, void* arg, size_t stack_bytes) {
    if (!fn) return NULL;
    if (stack_bytes == 0) stack_bytes = NXC_CORO_DEFAULT_STACK;
    if (stack_bytes < MIN_STACK) stack_bytes = MIN_STACK;
    stack_bytes = (stack_bytes + 15) & ~(size_t)15;
    nxc_coro* c = (nxc_coro*)calloc(1, sizeof *c);
    uint8_t* stack = (uint8_t*)aligned_alloc(16, stack_bytes);
    if (!c || !stack) {
        free(c);
        free(stack);
        return NULL;
    }
    memset(stack, STACK_FILL, stack_bytes);
    c->fn = fn;
    c->arg = arg;
    c->stack = stack;
    c->stack_size = stack_bytes;
    c->ctx.uc_stack.ss_sp = stack;
    c->ctx.uc_stack.ss_size = stack_bytes;
    c->ctx.uc_link = &c->caller;
    uint64_t p = (uint64_t)(uintptr_t)c;
    makecontext(&c->ctx, (void (*)(void))coro_main, 2, (int)(unsigned)p, (int)(unsigned)(p >> 32));
    return c;
}

static int guard_ok(const nxc_coro* c) {
    for (size_t i = 0; i < GUARD_BYTES; i++) {
        if (c->stack[i] != STACK_FILL) return 0;
    }
    return 1;
}

int nxc_coro_resume(nxc_coro* c) {
    if (!c || c->state != 0 || c->overflow) return -1;
    c->prev = t_current;
    t_current = c;
    c->state = 1;
    swapcontext(&c->caller, &c->ctx);
    t_current = c->prev;
    if (!guard_ok(c)) {
        c->overflow = 1;
        c->state = 2;
        nxc_log("coroutine stack overflow detected (stack size %zu): give nxc_coro_create a bigger stack", c->stack_size);
        return -1;
    }
    return c->state == 2 ? 0 : 1;
}

void nxc_coro_yield(void) {
    nxc_coro* c = t_current;
    if (!c) return;
    c->state = 0;
    swapcontext(&c->ctx, &c->caller);
}

int nxc_coro_done(const nxc_coro* c) { return !c || c->state == 2; }
nxc_coro* nxc_coro_current(void) { return t_current; }

size_t nxc_coro_stack_free(const nxc_coro* c) {
    if (!c) return 0;
    size_t n = GUARD_BYTES;
    while (n < c->stack_size && c->stack[n] == STACK_FILL) n++;
    return n - GUARD_BYTES;
}

void nxc_coro_stack_info(const nxc_coro* c, void** base, size_t* size) {
    if (base) *base = c ? c->stack : NULL;
    if (size) *size = c ? c->stack_size : 0;
}

void nxc_coro_destroy(nxc_coro* c) {
    if (!c) return;
    if (c->state == 1) {
        nxc_log("nxc_coro_destroy on a running coroutine ignored");
        return;
    }
    free(c->stack);
    free(c);
}
