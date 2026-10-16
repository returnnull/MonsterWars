// Horizon has no syslog; messages already go to stdout.
#ifndef SWITCH_COMPAT_SYSLOG_H
#define SWITCH_COMPAT_SYSLOG_H

#define LOG_EMERG 0
#define LOG_ALERT 1
#define LOG_CRIT 2
#define LOG_ERR 3
#define LOG_WARNING 4
#define LOG_NOTICE 5
#define LOG_INFO 6
#define LOG_DEBUG 7

#include <stdarg.h>

static inline void syslog(int p_priority, const char *p_format, ...) {}
static inline void vsyslog(int p_priority, const char *p_format, va_list p_args) {}
static inline void openlog(const char *p_ident, int p_option, int p_facility) {}
static inline void closelog(void) {}

#endif
