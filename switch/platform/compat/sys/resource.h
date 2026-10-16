// newlib's sys/resource.h lacks the rlimit API. Horizon has no resource
// limits, so getrlimit() reports none.
#ifndef SWITCH_COMPAT_SYS_RESOURCE_H
#define SWITCH_COMPAT_SYS_RESOURCE_H

#include_next <sys/resource.h>

#ifndef RLIMIT_STACK
#define RLIMIT_STACK 3
typedef unsigned long rlim_t;
struct rlimit {
	rlim_t rlim_cur;
	rlim_t rlim_max;
};
static inline int getrlimit(int p_resource, struct rlimit *r_limit) {
	r_limit->rlim_cur = 0;
	r_limit->rlim_max = 0;
	return 0;
}
static inline int setrlimit(int p_resource, const struct rlimit *p_limit) { return -1; }
#endif

#endif
