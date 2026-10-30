/* Nexvyn OS C apps: <stdio.h>. There is no FILE: read and write files with fs_read / fs_write (nexvyn.h).
   printf, puts and putchar write to the app's log (sdmc:/NexvynOS/System/Logs/Apps/<id>.log). */
#ifndef _STDIO_H
#define _STDIO_H
#include <stddef.h>
#include <stdarg.h>
#define EOF (-1)
int printf(const char* fmt, ...);
int puts(const char* s);
int putchar(int c);
int snprintf(char* buf, size_t size, const char* fmt, ...);
int vsnprintf(char* buf, size_t size, const char* fmt, va_list ap);
int sprintf(char* buf, const char* fmt, ...);
int vsprintf(char* buf, const char* fmt, va_list ap);
int sscanf(const char* s, const char* fmt, ...);
#endif
