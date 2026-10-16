/**************************************************************************/
/*  switch_wrapper.h                                                      */
/**************************************************************************/

// libnx uses names that clash with Godot classes, so include it with those
// names moved out of the way.

#ifndef SWITCH_WRAPPER_H
#define SWITCH_WRAPPER_H

#define Mutex LibnxMutex
#define Semaphore LibnxSemaphore
#define Thread LibnxThread
#define AudioDriver LibnxAudioDriver
#define Event LibnxEvent

#include <switch.h>

#undef Event
#undef AudioDriver
#undef Thread
#undef Semaphore
#undef Mutex

#endif // SWITCH_WRAPPER_H
