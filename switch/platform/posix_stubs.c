/**************************************************************************/
/*  posix_stubs.c                                                         */
/**************************************************************************/

// POSIX calls that drivers/unix references but newlib/libnx do not provide.
// Horizon cannot spawn processes or use signals, so these fail cleanly.

#include <errno.h>
#include <malloc.h>
#include <stddef.h>
#include <stdio.h>

int posix_memalign(void **r_ptr, size_t p_alignment, size_t p_size) {
	if (p_alignment < sizeof(void *) || (p_alignment & (p_alignment - 1)) != 0) {
		return EINVAL;
	}
	void *ptr = memalign(p_alignment, p_size);
	if (!ptr) {
		return ENOMEM;
	}
	*r_ptr = ptr;
	return 0;
}

int pthread_setname_np(void *p_thread, const char *p_name) {
	return 0;
}

int execvp(const char *p_file, char *const p_argv[]) {
	errno = ENOSYS;
	return -1;
}

int waitpid(int p_pid, int *r_status, int p_options) {
	errno = ECHILD;
	return -1;
}

int setsid(void) {
	errno = ENOSYS;
	return -1;
}

int pipe(int r_fds[2]) {
	errno = ENOSYS;
	return -1;
}

int mkfifo(const char *p_path, unsigned int p_mode) {
	errno = ENOSYS;
	return -1;
}

FILE *popen(const char *p_command, const char *p_mode) {
	errno = ENOSYS;
	return NULL;
}

int pclose(FILE *p_stream) {
	errno = ECHILD;
	return -1;
}

int sigaction(int p_signal, const void *p_action, void *r_old_action) {
	return 0;
}
