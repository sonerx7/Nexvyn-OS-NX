#pragma once

#include <stdlib.h>
#include <switch/kernel/random.h>

/* Expat selects arc4random_buf, but newlib's implementation needs a getentropy
 * syscall that this target does not supply. Use the OS-seeded generator. */
#define arc4random_buf randomGet
