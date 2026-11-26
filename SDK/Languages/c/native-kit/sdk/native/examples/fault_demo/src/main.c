/* Nexvyn Native SDK example: POSIX SIGSEGV hardware fault delivery via libnexvyn_compat.
 *
 * Installs a SA_SIGINFO SIGSEGV handler, guards a heap page read-only with nxn_mem_guard, executes a single
 * 4-byte AArch64 store to that page, and in the handler records si_addr / si_code / ESR WnR, edits a general
 * register and skips the faulting instruction (pc += 4) to resume safely without calling any nxn_* function or
 * taking a lock. Logs "FLT key=value" lines and finishes with "FLT END".
 *
 * On an emulator that does not enforce page protection (docs/current/n6/N6_PROBES.md row c), the store completes
 * without raising a fault; the demo detects 0 hits and reports "no fault delivered" cleanly instead of hanging. */
#include <malloc.h>
#include <nexvyn/nexvyn_native.h>
#include <signal.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ucontext.h>

#define DEMO_ID "com.nexvyn.example.faultdemo"
#define DEMO_REPORT "fault-demo.txt"
#define PAGE_SIZE 4096u
#define SENTINEL_VALUE 0x11223344u
#define WRITE_VALUE 0xDEADBEEFu
#define RESUME_REG_TAG UINT64_C(0xCAFEBABE)

static char g_report[4096];
static size_t g_report_len;

static void flt_log(const char* fmt, ...) {
    char line[320];
    va_list ap;
    va_start(ap, fmt);
    int n = vsnprintf(line, sizeof line, fmt, ap);
    va_end(ap);
    if (n < 0 || (size_t)n >= sizeof line) return;
    nxn_log(NXN_LOG_INFO, "%s", line);
    if ((size_t)n + 1 <= sizeof g_report - g_report_len) {
        memcpy(g_report + g_report_len, line, (size_t)n);
        g_report_len += (size_t)n;
        g_report[g_report_len++] = '\n';
    }
}

/* Exactly one faultable 4-byte store followed by a register move and return. No live x17.
 * On a guarded read-only page, the SIGSEGV handler advances pc by 4 and sets regs[1] = RESUME_REG_TAG. */
extern uint64_t fault_demo_store(volatile uint32_t* addr, uint64_t reg_marker, uint32_t value);
extern const char fault_demo_store_pc[];
__asm__(".pushsection .text.fault_demo_store,\"ax\",%progbits\n"
        ".balign 4\n"
        ".global fault_demo_store, fault_demo_store_pc\n"
        ".hidden fault_demo_store, fault_demo_store_pc\n"
        ".type fault_demo_store, %function\n"
        "fault_demo_store:\n"
        "fault_demo_store_pc:\n"
        "str w2, [x0]\n"
        "mov x0, x1\n"
        "ret\n"
        ".size fault_demo_store, .-fault_demo_store\n"
        ".popsection\n");

typedef struct fault_record {
    volatile uintptr_t expected_addr;
    volatile unsigned hits;
    volatile int signo;
    volatile int si_code;
    volatile uintptr_t si_addr;
    volatile uint64_t fault_pc;
    volatile uint64_t fault_esr;
    volatile int is_write;
} fault_record;

static fault_record g_fault;

/* Runs on the faulting thread's stack. Must not call nxn_* functions, allocate, or lock. */
static void on_segv(int sig, siginfo_t* si, void* uctx) {
    ucontext_t* uc = (ucontext_t*)uctx;
    if (!si || !uc) return;
    if (g_fault.hits != 0) return;
    g_fault.hits = 1;
    g_fault.signo = sig;
    g_fault.si_code = si->si_code;
    g_fault.si_addr = (uintptr_t)si->si_addr;
    g_fault.fault_pc = uc->uc_mcontext.pc;
    g_fault.fault_esr = uc->uc_mcontext.esr;
    g_fault.is_write = nxc_fault_is_write(uc);
    if (uc->uc_mcontext.pc == (uint64_t)(uintptr_t)fault_demo_store_pc &&
        (uintptr_t)si->si_addr == g_fault.expected_addr) {
        uc->uc_mcontext.regs[1] = RESUME_REG_TAG;
        uc->uc_mcontext.pc += 4u;
    }
}

static int app_main(int argc, char** argv) {
    (void)argc;
    (void)argv;

    nxn_caps caps = NXN_STRUCT_INIT(nxn_caps);
    nxn_result caps_rc = nxn_caps_get(&caps);
    unsigned has_fault = (caps_rc == NXN_OK && (caps.features & NXN_CAP_FAULT_HANDLER)) ? 1u : 0u;
    unsigned has_guard = (caps_rc == NXN_OK && (caps.features & NXN_CAP_GUARD_PAGES)) ? 1u : 0u;
    flt_log("FLT caps=%s runtime=%s fault_cap=%u guard_cap=%u",
            caps_rc == NXN_OK ? "ok" : "fail",
            (caps.features & NXN_CAP_WINDOWED) ? "windowed" : "standalone",
            has_fault, has_guard);

    if (!has_fault || !has_guard) {
        flt_log("FLT status=unsupported reason=%s", !has_fault ? "no_fault_cap" : "no_guard_cap");
        flt_log("FLT END");
        nxn_fs_write(NXN_DIR_DATA, DEMO_REPORT, g_report, g_report_len);
        return 0;
    }

    void* block = memalign(PAGE_SIZE, 3u * PAGE_SIZE);
    if (!block) {
        flt_log("FLT status=fail reason=alloc");
        flt_log("FLT END");
        nxn_fs_write(NXN_DIR_DATA, DEMO_REPORT, g_report, g_report_len);
        return 1;
    }

    volatile uint32_t* page = (volatile uint32_t*)((char*)block + PAGE_SIZE);
    *page = SENTINEL_VALUE;
    memset(&g_fault, 0, sizeof g_fault);
    g_fault.expected_addr = (uintptr_t)page;

    struct sigaction sa, old_sa;
    memset(&sa, 0, sizeof sa);
    memset(&old_sa, 0, sizeof old_sa);
    sa.sa_sigaction = on_segv;
    sa.sa_flags = SA_SIGINFO;
    sigemptyset(&sa.sa_mask);

    int sa_rc = sigaction(SIGSEGV, &sa, &old_sa);
    flt_log("FLT sigaction=%s rc=%d", sa_rc == 0 ? "ok" : "fail", sa_rc);
    if (sa_rc != 0) {
        free(block);
        flt_log("FLT status=fail reason=sigaction");
        flt_log("FLT END");
        nxn_fs_write(NXN_DIR_DATA, DEMO_REPORT, g_report, g_report_len);
        return 1;
    }

    nxn_result guard_rc = nxn_mem_guard(block, PAGE_SIZE, PAGE_SIZE, NXN_GUARD_READONLY);
    flt_log("FLT guard=%s mode=readonly rc=%d", guard_rc == NXN_OK ? "ok" : "fail", (int)guard_rc);
    if (guard_rc != NXN_OK) {
        sigaction(SIGSEGV, &old_sa, NULL);
        free(block);
        flt_log("FLT status=%s reason=guard_failed",
                guard_rc == NXN_ERR_UNSUPPORTED ? "unsupported" : "fail");
        flt_log("FLT END");
        nxn_fs_write(NXN_DIR_DATA, DEMO_REPORT, g_report, g_report_len);
        return guard_rc == NXN_ERR_UNSUPPORTED ? 0 : 1;
    }

    uint64_t reg_out = fault_demo_store(page, 0, WRITE_VALUE);

    nxn_result lift_rc = nxn_mem_guard(block, PAGE_SIZE, PAGE_SIZE, NXN_GUARD_OFF);
    sigaction(SIGSEGV, &old_sa, NULL);
    uint32_t observed = *page;
    free(block);

    flt_log("FLT lift=%s rc=%d", lift_rc == NXN_OK ? "ok" : "fail", (int)lift_rc);

    int exit_code = 0;
    if (g_fault.hits == 0) {
        /* the emulator does not enforce page protection (docs/current/n6/N6_PROBES.md row c). */
        flt_log("FLT fault=none hits=0 value=%08x", (unsigned)observed);
        flt_log("FLT status=no_fault_delivered");
        nxn_log(NXN_LOG_INFO, "no fault delivered: page protection is not enforced in this environment");
    } else {
        int addr_match = (g_fault.si_addr == g_fault.expected_addr);
        int pc_match = (g_fault.fault_pc == (uint64_t)(uintptr_t)fault_demo_store_pc);
        int reg_edit = (reg_out == RESUME_REG_TAG);
        int intact = (observed == SENTINEL_VALUE);
        int code_ok = (g_fault.si_code == SEGV_ACCERR);
        int ok = (g_fault.hits == 1 && g_fault.signo == SIGSEGV && code_ok && addr_match &&
                  pc_match && g_fault.is_write == 1 && reg_edit && intact && lift_rc == NXN_OK);
        flt_log("FLT fault=delivered hits=%u signo=%d si_code=%d addr_match=%d pc_match=%d write=%d reg_edit=%d intact=%d esr=%08llx",
                g_fault.hits, g_fault.signo, g_fault.si_code, addr_match, pc_match,
                g_fault.is_write, reg_edit, intact, (unsigned long long)g_fault.fault_esr);
        flt_log("FLT status=%s", ok ? "ok" : "fail");
        exit_code = ok ? 0 : 1;
    }

    flt_log("FLT END");
    nxn_fs_write(NXN_DIR_DATA, DEMO_REPORT, g_report, g_report_len);
    return exit_code;
}

int main(int argc, char** argv) {
    nxn_init_params params = NXN_STRUCT_INIT(nxn_init_params);
    params.standalone_id = DEMO_ID;
    return nxn_run(argc, argv, app_main, &params);
}
