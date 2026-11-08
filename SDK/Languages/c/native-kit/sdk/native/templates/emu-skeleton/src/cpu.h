// Emulator skeleton: guest CPU state and the interpreter loop. Replace the toy ISA with the real one.
#pragma once
#include <cstddef>
#include <cstdint>
#include <vector>

struct Cpu {
    uint32_t r[16] = {};
    uint32_t pc = 0;
    bool halted = false;
    std::vector<uint8_t> mem;  // guest RAM; big cores map it with a page table instead of a flat vector

    explicit Cpu(size_t ramSize) : mem(ramSize) {}
    uint32_t read32(uint32_t addr) const;
    void write32(uint32_t addr, uint32_t v);
    // Executes up to `cycles` instructions and returns how many ran (the frame budget of the emulated machine).
    int run(int cycles);
};
