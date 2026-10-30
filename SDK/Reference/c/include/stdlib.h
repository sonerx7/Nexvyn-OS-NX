/* Nexvyn OS C apps: <stdlib.h>. malloc is counted against the app's 64 MB (NULL past it); everything still allocated
   is freed when the window closes. There is no exit(): call sys_exit() (nexvyn.h) to close the window. */
#ifndef _STDLIB_H
#define _STDLIB_H
#include <stddef.h>
#define RAND_MAX 0x7fffffff
void* malloc(size_t n);
void* calloc(size_t n, size_t size);
void* realloc(void* p, size_t n);
void free(void* p);
int atoi(const char* s);
long atol(const char* s);
double atof(const char* s);
long strtol(const char* s, char** end, int base);
unsigned long strtoul(const char* s, char** end, int base);
long long strtoll(const char* s, char** end, int base);
unsigned long long strtoull(const char* s, char** end, int base);
double strtod(const char* s, char** end);
float strtof(const char* s, char** end);
int abs(int v);
long labs(long v);
long long llabs(long long v);
void qsort(void* base, size_t n, size_t size, int (*cmp)(const void*, const void*));
void* bsearch(const void* key, const void* base, size_t n, size_t size, int (*cmp)(const void*, const void*));
int rand(void);
void srand(unsigned seed);
#endif
