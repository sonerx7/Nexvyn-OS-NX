/* Minimal libintl.h for the Nexvyn native sysroot: every message is returned untranslated.
 *
 * newlib has no gettext, glib refuses to build without a libintl, and its own fallback (frida/proxy-libintl) is a git
 * wrap. This header-only stand-in has the same job: the functions glib calls, all pass-through. Apps translate through
 * their own lang/*.json files, not through gettext. MIT licence (Nexvyn Project).
 */
#ifndef NEXVYN_PROXY_LIBINTL_H
#define NEXVYN_PROXY_LIBINTL_H

#include <locale.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifndef LC_MESSAGES
#define LC_MESSAGES 5
#endif

static inline char *gettext(const char *msgid) { return (char *)msgid; }
static inline char *dgettext(const char *domain, const char *msgid) { (void)domain; return (char *)msgid; }
static inline char *dcgettext(const char *domain, const char *msgid, int category)
{
    (void)domain; (void)category;
    return (char *)msgid;
}
static inline char *ngettext(const char *msgid1, const char *msgid2, unsigned long n)
{
    return (char *)(n == 1 ? msgid1 : msgid2);
}
static inline char *dngettext(const char *domain, const char *msgid1, const char *msgid2, unsigned long n)
{
    (void)domain;
    return (char *)(n == 1 ? msgid1 : msgid2);
}
static inline char *dcngettext(const char *domain, const char *msgid1, const char *msgid2, unsigned long n, int category)
{
    (void)domain; (void)category;
    return (char *)(n == 1 ? msgid1 : msgid2);
}
static inline char *textdomain(const char *domain) { return (char *)(domain ? domain : "messages"); }
static inline char *bindtextdomain(const char *domain, const char *dir) { (void)domain; return (char *)dir; }
static inline char *bind_textdomain_codeset(const char *domain, const char *codeset)
{
    (void)domain;
    return (char *)codeset;
}

#ifdef __cplusplus
}
#endif

#endif
