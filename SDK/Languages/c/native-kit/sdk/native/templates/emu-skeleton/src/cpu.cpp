// Toy ISA: 32-bit words, op = bits 31..24, a = bits 23..20, b = bits 19..16, imm = bits 15..0.
//   0x01 MOVI a,imm   0x02 ADD a,b   0x03 JNZ a,imm   0x04 DEC a   0xFF HALT
#include "cpu.h"
#include <cstring>

uint32_t Cpu::read32(uint32_t addr) const {
    uint32_t v = 0;
    if (addr + 4 <= mem.size()) std::memcpy(&v, &mem[addr], 4);  // out of range reads 0: never crash the host
    return v;
}

void Cpu::write32(uint32_t addr, uint32_t v) {
    if (addr + 4 <= mem.size()) std::memcpy(&mem[addr], &v, 4);
}

int Cpu::run(int cycles) {
    int n = 0;
    while (n < cycles && !halted) {  // fetch / decode / execute
        uint32_t w = read32(pc);
        pc += 4;
        uint32_t op = w >> 24, a = (w >> 20) & 15, b = (w >> 16) & 15, imm = w & 0xFFFF;
        switch (op) {
            case 0x01: r[a] = imm; break;
            case 0x02: r[a] += r[b]; break;
            case 0x03: if (r[a] != 0) pc = imm; break;
            case 0x04: r[a]--; break;
            default: halted = true; break;  // HALT or unknown opcode: stop, never crash the host
        }
        n++;
    }
    return n;
}
