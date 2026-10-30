/* Nexvyn OS C apps: <assert.h>. A failed assert stops the app with the error screen. */
#ifndef _ASSERT_H
#define _ASSERT_H
void __nxv_assert(const char* expr, const char* file, int line);
#ifdef NDEBUG
#define assert(e) ((void)0)
#else
#define assert(e) ((e) ? (void)0 : __nxv_assert(#e, __FILE__, __LINE__))
#endif
#endif
