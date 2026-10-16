// Horizon has no dynamic linker. Godot and glad only use these to load
// optional libraries, so they simply report that nothing can be loaded.
#ifndef SWITCH_COMPAT_DLFCN_H
#define SWITCH_COMPAT_DLFCN_H

#define RTLD_LAZY 0x0001
#define RTLD_NOW 0x0002
#define RTLD_GLOBAL 0x0100
#define RTLD_LOCAL 0
#define RTLD_DEFAULT ((void *)0)

typedef struct {
	const char *dli_fname;
	void *dli_fbase;
	const char *dli_sname;
	void *dli_saddr;
} Dl_info;

static inline void *dlopen(const char *p_file, int p_mode) { return (void *)0; }
static inline int dlclose(void *p_handle) { return 0; }
static inline void *dlsym(void *p_handle, const char *p_name) { return (void *)0; }
static inline char *dlerror(void) { return (char *)"dynamic libraries are not supported on Switch"; }
static inline int dladdr(const void *p_addr, Dl_info *p_info) { return 0; }

#endif
