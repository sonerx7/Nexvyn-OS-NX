/* greet.nxvlib - the interface of the template library. Only C types cross a library boundary: no C++ classes,
 * exceptions or thread_local. The app looks the functions up by name (nxn_lib_sym / dlsym), so it keeps working with
 * any 1.x version of the library; add functions, never change or remove one (raise the major version instead). */
#ifndef GREET_H
#define GREET_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef const char* (*greet_hello_fn)(void);
typedef int (*greet_format_fn)(char* out, size_t size, const char* who);

const char* greet_hello(void);                           /* a constant string inside the library */
int greet_format(char* out, size_t size, const char* who); /* uses the app's snprintf; counts its calls */

#ifdef __cplusplus
}
#endif
#endif
