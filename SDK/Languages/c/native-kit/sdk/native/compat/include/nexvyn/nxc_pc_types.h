/* Nexvyn compat: PC type and function names for decompilation ports and other code written against the Win32 / MSVC C
 * runtime vocabulary. Header only (static inline), no library needed. It is a naming bridge, not an emulation of Win32:
 * HANDLE is opaque and nothing here opens kernel objects.
 *
 * Define NXC_PC_MINMAX before including to get the min() / max() macros (off by default: they collide with C++). */
#ifndef NEXVYN_NXC_PC_TYPES_H
#define NEXVYN_NXC_PC_TYPES_H

#include <errno.h>
#include <limits.h>
#include <stdarg.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <time.h>
#include <unistd.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ---- fixed size types ---- */
typedef int BOOL;
typedef unsigned char BYTE;
typedef unsigned short WORD;
typedef uint32_t DWORD;
typedef uint64_t QWORD;
typedef int32_t LONG;
typedef uint32_t ULONG;
typedef int16_t SHORT;
typedef uint16_t USHORT;
typedef int INT;
typedef unsigned int UINT;
typedef int64_t LONGLONG;
typedef uint64_t ULONGLONG;
typedef int64_t INT64;
typedef uint64_t UINT64;
typedef int32_t INT32;
typedef uint32_t UINT32;
typedef int16_t INT16;
typedef uint16_t UINT16;
typedef int8_t INT8;
typedef uint8_t UINT8;
typedef char CHAR;
typedef unsigned char UCHAR;
typedef uint16_t WCHAR;
typedef float FLOAT;
typedef void VOID;
typedef void* PVOID;
typedef void* LPVOID;
typedef const void* LPCVOID;
typedef char* LPSTR;
typedef const char* LPCSTR;
typedef BYTE* LPBYTE;
typedef DWORD* LPDWORD;
typedef BOOL* LPBOOL;
typedef intptr_t INT_PTR;
typedef uintptr_t UINT_PTR;
typedef intptr_t LONG_PTR;
typedef uintptr_t ULONG_PTR;
typedef uintptr_t DWORD_PTR;
typedef size_t SIZE_T;
typedef intptr_t SSIZE_T;
typedef UINT_PTR WPARAM;
typedef LONG_PTR LPARAM;
typedef LONG_PTR LRESULT;
typedef LONG HRESULT;

/* An opaque pointer: two different kinds of handle stay different types only if you declare them with DECLARE_HANDLE. */
typedef struct nxc_handle_s* HANDLE;
#define DECLARE_HANDLE(name) typedef struct name##__ { int unused; }* name
#define INVALID_HANDLE_VALUE ((HANDLE)(intptr_t)-1)

typedef union _LARGE_INTEGER {
    struct {
        DWORD LowPart;
        LONG HighPart;
    } u;
    LONGLONG QuadPart;
} LARGE_INTEGER;

#ifndef TRUE
#define TRUE 1
#endif
#ifndef FALSE
#define FALSE 0
#endif

/* ---- calling convention noise ---- */
#ifndef __cdecl
#define __cdecl
#endif
#ifndef __stdcall
#define __stdcall
#endif
#ifndef __fastcall
#define __fastcall
#endif
#define __declspec(x)
#define WINAPI
#define CALLBACK
#define APIENTRY
#define PASCAL
#define FAR
#define NEAR
#define CONST const

/* ---- sizes and macros ---- */
#define MAX_PATH 260
#define _MAX_PATH 260
#define _MAX_FNAME 256
#define _MAX_EXT 256
#define _MAX_DIR 256
#define _MAX_DRIVE 3
#ifndef _countof
#define _countof(a) (sizeof(a) / sizeof((a)[0]))
#endif
#define ARRAYSIZE(a) _countof(a)
#define LOBYTE(w) ((BYTE)((DWORD_PTR)(w) & 0xff))
#define HIBYTE(w) ((BYTE)(((DWORD_PTR)(w) >> 8) & 0xff))
#define LOWORD(l) ((WORD)((DWORD_PTR)(l) & 0xffff))
#define HIWORD(l) ((WORD)(((DWORD_PTR)(l) >> 16) & 0xffff))
#define MAKEWORD(a, b) ((WORD)(((BYTE)((DWORD_PTR)(a) & 0xff)) | ((WORD)((BYTE)((DWORD_PTR)(b) & 0xff))) << 8))
#define MAKELONG(a, b) ((LONG)(((WORD)((DWORD_PTR)(a) & 0xffff)) | ((DWORD)((WORD)((DWORD_PTR)(b) & 0xffff))) << 16))
#define ZeroMemory(p, n) memset((p), 0, (n))
#define SecureZeroMemory(p, n) memset((p), 0, (n))
#define CopyMemory(d, s, n) memcpy((d), (s), (n))
#define MoveMemory(d, s, n) memmove((d), (s), (n))
#define FillMemory(p, n, v) memset((p), (v), (n))
#define UNREFERENCED_PARAMETER(p) ((void)(p))
#ifdef NXC_PC_MINMAX
#ifndef min
#define min(a, b) (((a) < (b)) ? (a) : (b))
#endif
#ifndef max
#define max(a, b) (((a) > (b)) ? (a) : (b))
#endif
#endif

/* ---- C runtime names ---- */
static inline int stricmp(const char* a, const char* b) { return strcasecmp(a, b); }
static inline int strnicmp(const char* a, const char* b, size_t n) { return strncasecmp(a, b, n); }
static inline int _stricmp(const char* a, const char* b) { return strcasecmp(a, b); }
static inline int _strnicmp(const char* a, const char* b, size_t n) { return strncasecmp(a, b, n); }
static inline char* _strdup(const char* s) { return strdup(s); }
static inline int _snprintf(char* d, size_t n, const char* f, ...) __attribute__((format(printf, 3, 4)));
static inline int _snprintf(char* d, size_t n, const char* f, ...) {
    va_list ap;
    va_start(ap, f);
    int r = vsnprintf(d, n, f, ap);
    va_end(ap);
    return r;
}
static inline int _vsnprintf(char* d, size_t n, const char* f, va_list ap) { return vsnprintf(d, n, f, ap); }
static inline int _unlink(const char* p) { return unlink(p); }
static inline int _access(const char* p, int m) { return access(p, m); }
static inline char* _getcwd(char* b, int n) { return getcwd(b, (size_t)n); }
static inline int _chdir(const char* p) { return chdir(p); }
static inline int _rmdir(const char* p) { return rmdir(p); }
static inline int _close(int fd) { return close(fd); }
static inline int _read(int fd, void* b, unsigned n) { return (int)read(fd, b, n); }
static inline int _write(int fd, const void* b, unsigned n) { return (int)write(fd, b, n); }
static inline int _isatty(int fd) { return isatty(fd); }
static inline char* _strupr(char* s) {
    for (char* p = s; *p; p++) if (*p >= 'a' && *p <= 'z') *p = (char)(*p - 32);
    return s;
}
static inline char* _strlwr(char* s) {
    for (char* p = s; *p; p++) if (*p >= 'A' && *p <= 'Z') *p = (char)(*p + 32);
    return s;
}
#ifndef _ERRNO_T_DEFINED
#define _ERRNO_T_DEFINED
typedef int errno_t;
#endif
static inline errno_t strcpy_s(char* d, size_t n, const char* s) {
    if (!d || !n) return EINVAL;
    if (!s) {
        d[0] = 0;
        return EINVAL;
    }
    size_t l = strlen(s);
    if (l >= n) {
        d[0] = 0;
        return ERANGE;
    }
    memcpy(d, s, l + 1);
    return 0;
}
static inline errno_t strcat_s(char* d, size_t n, const char* s) {
    size_t dl = d ? strnlen(d, n) : 0;
    if (!d || dl >= n || !s) return EINVAL;
    size_t l = strlen(s);
    if (dl + l >= n) {
        d[0] = 0;
        return ERANGE;
    }
    memcpy(d + dl, s, l + 1);
    return 0;
}

/* ---- time ---- */
static inline void Sleep(DWORD ms) {
    struct timespec ts;
    ts.tv_sec = (time_t)(ms / 1000u);
    ts.tv_nsec = (long)(ms % 1000u) * 1000000L;
    nanosleep(&ts, NULL);
}

static inline ULONGLONG GetTickCount64(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (ULONGLONG)ts.tv_sec * 1000u + (ULONGLONG)ts.tv_nsec / 1000000u;
}

static inline DWORD GetTickCount(void) { return (DWORD)GetTickCount64(); }
static inline DWORD timeGetTime(void) { return (DWORD)GetTickCount64(); }

static inline BOOL QueryPerformanceFrequency(LARGE_INTEGER* f) {
    f->QuadPart = 1000000000;
    return TRUE;
}

static inline BOOL QueryPerformanceCounter(LARGE_INTEGER* c) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    c->QuadPart = (LONGLONG)ts.tv_sec * 1000000000 + ts.tv_nsec;
    return TRUE;
}

static inline DWORD GetLastError(void) { return (DWORD)errno; }
static inline void SetLastError(DWORD e) { errno = (int)e; }

#ifdef __cplusplus
}
#endif
#endif
