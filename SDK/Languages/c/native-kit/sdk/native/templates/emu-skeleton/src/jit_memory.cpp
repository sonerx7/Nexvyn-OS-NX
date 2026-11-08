// TODO(emulator author): the interpreter in cpu.cpp works without this. To add a JIT:
//   1. libnx jitCreate() gives RW and RX views, but it needs code-memory support, which is not always granted to an
//      nro started as an applet. Under the Nexvyn ABI use the kit's JIT allocator once it exists (NEXVYN_ABI).
//   2. Always keep the interpreter as the fallback when create() returns false.
#include "jit_memory.h"
#include <cstdlib>
#include <switch.h>

static Jit g_jit;

bool JitMemory::create(size_t bytes) {
    size = bytes;
    if (R_SUCCEEDED(jitCreate(&g_jit, bytes))) {
        rw = jitGetRwAddr(&g_jit);
        rx = jitGetRxAddr(&g_jit);
        real = true;
        return true;
    }
    rw = rx = std::malloc(bytes);  // NOT executable: a stand-in so the rest of the core can be written and tested
    real = false;
    return false;
}

void JitMemory::beginWrite() { if (real) jitTransitionToWritable(&g_jit); }
void JitMemory::endWrite() { if (real) jitTransitionToExecutable(&g_jit); }

void JitMemory::destroy() {
    if (real) jitClose(&g_jit); else std::free(rw);
    rw = rx = nullptr;
    real = false;
}
