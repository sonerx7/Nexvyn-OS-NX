// Placeholder for JIT code memory. A recompiling core writes host machine code here and jumps into it.
#pragma once
#include <cstddef>

struct JitMemory {
    void* rw = nullptr;  // address to write code through
    void* rx = nullptr;  // address to execute code from (differs from rw: the OS splits write and execute views)
    size_t size = 0;
    bool real = false;   // true when the memory is really executable

    bool create(size_t bytes);
    void beginWrite();   // call before emitting code
    void endWrite();     // call before running the code (makes it executable)
    void destroy();
};
