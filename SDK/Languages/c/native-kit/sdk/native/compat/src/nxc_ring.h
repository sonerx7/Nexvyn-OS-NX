/* Nexvyn compat layer - byte ring buffer used by pipe(). Pure C, no OS calls: the host tests compile it as is. */
#ifndef NXC_RING_H
#define NXC_RING_H

#include <stddef.h>
#include <stdint.h>
#include <string.h>

typedef struct nxc_ring {
    uint8_t* buf;
    size_t cap;
    size_t head; /* index of the oldest byte */
    size_t len;  /* bytes stored */
} nxc_ring;

static inline void nxc_ring_init(nxc_ring* r, void* storage, size_t cap) {
    r->buf = (uint8_t*)storage;
    r->cap = cap;
    r->head = 0;
    r->len = 0;
}

static inline size_t nxc_ring_free(const nxc_ring* r) { return r->cap - r->len; }

/* Appends up to n bytes, returns how many fit. */
static inline size_t nxc_ring_write(nxc_ring* r, const void* data, size_t n) {
    size_t room = r->cap - r->len;
    if (n > room) n = room;
    size_t tail = r->head + r->len;
    if (tail >= r->cap) tail -= r->cap;
    size_t first = r->cap - tail;
    if (first > n) first = n;
    memcpy(r->buf + tail, data, first);
    if (n > first) memcpy(r->buf, (const uint8_t*)data + first, n - first);
    r->len += n;
    return n;
}

/* Removes up to n bytes into out, returns how many were there. */
static inline size_t nxc_ring_read(nxc_ring* r, void* out, size_t n) {
    if (n > r->len) n = r->len;
    size_t first = r->cap - r->head;
    if (first > n) first = n;
    memcpy(out, r->buf + r->head, first);
    if (n > first) memcpy((uint8_t*)out + first, r->buf, n - first);
    r->head += n;
    if (r->head >= r->cap) r->head -= r->cap;
    r->len -= n;
    if (r->len == 0) r->head = 0;
    return n;
}

#endif
