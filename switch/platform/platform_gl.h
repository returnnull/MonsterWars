/**************************************************************************/
/*  platform_gl.h                                                         */
/**************************************************************************/

#ifndef PLATFORM_GL_H
#define PLATFORM_GL_H

#ifndef GL_API_ENABLED
#define GL_API_ENABLED // Mesa on Horizon provides desktop OpenGL.
#endif

#ifndef GLES_API_ENABLED
#define GLES_API_ENABLED
#endif

#include <EGL/egl.h>
#include <EGL/eglext.h>

#include "thirdparty/glad/glad/gl.h"

#endif // PLATFORM_GL_H
