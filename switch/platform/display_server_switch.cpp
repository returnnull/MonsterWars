/**************************************************************************/
/*  display_server_switch.cpp                                             */
/**************************************************************************/

#include "display_server_switch.h"

#include "os_switch.h"
#include "switch_wrapper.h"

#include "core/config/project_settings.h"
#include "drivers/gles3/rasterizer_gles3.h"
#include "servers/display/native_menu.h"

Vector<String> DisplayServerSwitch::get_rendering_drivers_func() {
	Vector<String> drivers;
	drivers.push_back("opengl3");
	return drivers;
}

DisplayServer *DisplayServerSwitch::create_func(const String &p_rendering_driver, DisplayServer::WindowMode p_mode, DisplayServer::VSyncMode p_vsync_mode, uint32_t p_flags, const Vector2i *p_position, const Vector2i &p_resolution, int p_screen, Context p_context, int64_t p_parent_window, Error &r_error) {
	DisplayServerSwitch *ds = memnew(DisplayServerSwitch(r_error));
	if (r_error != OK) {
		OS::get_singleton()->alert("Could not create an OpenGL 3.3 context through EGL.", "Unable to initialize video driver");
	}
	ds->window_set_vsync_mode(p_vsync_mode);
	return ds;
}

void DisplayServerSwitch::register_switch_driver() {
	register_create_function("switch", create_func, get_rendering_drivers_func);
}

Error DisplayServerSwitch::_init_egl() {
	egl_display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
	if (egl_display == EGL_NO_DISPLAY) {
		ERR_PRINT(vformat("eglGetDisplay failed: 0x%x", eglGetError()));
		return ERR_UNAVAILABLE;
	}
	if (!eglInitialize(egl_display, nullptr, nullptr)) {
		ERR_PRINT(vformat("eglInitialize failed: 0x%x", eglGetError()));
		return ERR_UNAVAILABLE;
	}
	if (!eglBindAPI(EGL_OPENGL_API)) {
		ERR_PRINT(vformat("eglBindAPI failed: 0x%x", eglGetError()));
		return ERR_UNAVAILABLE;
	}

	static const EGLint config_attribs[] = {
		EGL_RENDERABLE_TYPE, EGL_OPENGL_BIT,
		EGL_RED_SIZE, 8,
		EGL_GREEN_SIZE, 8,
		EGL_BLUE_SIZE, 8,
		EGL_ALPHA_SIZE, 8,
		EGL_DEPTH_SIZE, 24,
		EGL_STENCIL_SIZE, 8,
		EGL_NONE
	};
	EGLConfig config;
	EGLint num_configs = 0;
	eglChooseConfig(egl_display, config_attribs, &config, 1, &num_configs);
	if (num_configs == 0) {
		ERR_PRINT(vformat("eglChooseConfig found nothing: 0x%x", eglGetError()));
		return ERR_UNAVAILABLE;
	}

	NWindow *win = nwindowGetDefault();
	nwindowSetDimensions(win, size.width, size.height);
	egl_surface = eglCreateWindowSurface(egl_display, config, win, nullptr);
	if (egl_surface == EGL_NO_SURFACE) {
		ERR_PRINT(vformat("eglCreateWindowSurface failed: 0x%x", eglGetError()));
		return ERR_UNAVAILABLE;
	}

	static const EGLint context_attribs[] = {
		EGL_CONTEXT_OPENGL_PROFILE_MASK_KHR, EGL_CONTEXT_OPENGL_CORE_PROFILE_BIT_KHR,
		EGL_CONTEXT_MAJOR_VERSION_KHR, 3,
		EGL_CONTEXT_MINOR_VERSION_KHR, 3,
		EGL_NONE
	};
	egl_context = eglCreateContext(egl_display, config, EGL_NO_CONTEXT, context_attribs);
	if (egl_context == EGL_NO_CONTEXT) {
		ERR_PRINT(vformat("eglCreateContext failed: 0x%x", eglGetError()));
		return ERR_UNAVAILABLE;
	}

	eglMakeCurrent(egl_display, egl_surface, egl_surface, egl_context);
	return OK;
}

DisplayServerSwitch::DisplayServerSwitch(Error &r_error) {
	native_menu = memnew(NativeMenu);
	Input::get_singleton()->set_event_dispatch_function(_dispatch_input_events);

	// The game renders at 720p and the console scales it up when docked.
	size = Size2i(1280, 720);

	r_error = _init_egl();
	if (r_error == OK) {
		RasterizerGLES3::make_current(true);
	}

	hidInitializeTouchScreen();
}

DisplayServerSwitch::~DisplayServerSwitch() {
	if (egl_display != EGL_NO_DISPLAY) {
		eglMakeCurrent(egl_display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
		if (egl_context != EGL_NO_CONTEXT) {
			eglDestroyContext(egl_display, egl_context);
		}
		if (egl_surface != EGL_NO_SURFACE) {
			eglDestroySurface(egl_display, egl_surface);
		}
		eglTerminate(egl_display);
	}
	if (native_menu) {
		memdelete(native_menu);
		native_menu = nullptr;
	}
}

bool DisplayServerSwitch::has_feature(Feature p_feature) const {
	switch (p_feature) {
		case FEATURE_TOUCHSCREEN:
		case FEATURE_VIRTUAL_KEYBOARD:
			return true;
		default:
			return false;
	}
}

void DisplayServerSwitch::window_set_vsync_mode(VSyncMode p_vsync_mode, WindowID p_window) {
	vsync_mode = p_vsync_mode;
	if (egl_display != EGL_NO_DISPLAY) {
		eglSwapInterval(egl_display, p_vsync_mode == VSYNC_DISABLED ? 0 : 1);
	}
}

void DisplayServerSwitch::screen_set_keep_on(bool p_enable) {
	appletSetMediaPlaybackState(p_enable);
}

void DisplayServerSwitch::swap_buffers() {
	eglSwapBuffers(egl_display, egl_surface);
}

void DisplayServerSwitch::_process_touch() {
	HidTouchScreenState state = {};
	if (!hidGetTouchScreenStates(&state, 1)) {
		return;
	}

	const Vector2 scale = Vector2(size) / Vector2(1280, 720);

	// Release fingers that were lifted.
	for (int i = 0; i < touch_count; i++) {
		bool still_down = false;
		for (int j = 0; j < state.count; j++) {
			if ((int)state.touches[j].finger_id == touch_id[i]) {
				still_down = true;
				break;
			}
		}
		if (!still_down) {
			Ref<InputEventScreenTouch> ev;
			ev.instantiate();
			ev->set_index(touch_id[i]);
			ev->set_position(touch_pos[i]);
			ev->set_pressed(false);
			Input::get_singleton()->parse_input_event(ev);
		}
	}

	int new_count = 0;
	Vector2 new_pos[16];
	int new_id[16];
	for (int j = 0; j < state.count && j < 16; j++) {
		const HidTouchState &t = state.touches[j];
		Vector2 pos = Vector2(t.x, t.y) * scale;
		int previous = -1;
		for (int i = 0; i < touch_count; i++) {
			if (touch_id[i] == (int)t.finger_id) {
				previous = i;
				break;
			}
		}
		if (previous < 0) {
			Ref<InputEventScreenTouch> ev;
			ev.instantiate();
			ev->set_index(t.finger_id);
			ev->set_position(pos);
			ev->set_pressed(true);
			Input::get_singleton()->parse_input_event(ev);
		} else if (touch_pos[previous] != pos) {
			Ref<InputEventScreenDrag> ev;
			ev.instantiate();
			ev->set_index(t.finger_id);
			ev->set_position(pos);
			ev->set_relative(pos - touch_pos[previous]);
			ev->set_relative_screen_position(pos - touch_pos[previous]);
			Input::get_singleton()->parse_input_event(ev);
		}
		new_pos[new_count] = pos;
		new_id[new_count] = t.finger_id;
		new_count++;
	}

	touch_count = new_count;
	for (int i = 0; i < new_count; i++) {
		touch_pos[i] = new_pos[i];
		touch_id[i] = new_id[i];
	}
}

void DisplayServerSwitch::_process_focus() {
	bool now_focused = appletGetFocusState() == AppletFocusState_InFocus;
	if (now_focused == focused) {
		return;
	}
	focused = now_focused;
	if (window_event_callback.is_valid()) {
		window_event_callback.call(focused ? WINDOW_EVENT_FOCUS_IN : WINDOW_EVENT_FOCUS_OUT);
	}
	if (OS::get_singleton()->get_main_loop()) {
		OS::get_singleton()->get_main_loop()->notification(focused ? MainLoop::NOTIFICATION_APPLICATION_FOCUS_IN : MainLoop::NOTIFICATION_APPLICATION_FOCUS_OUT);
	}
}

void DisplayServerSwitch::process_events() {
	_process_focus();
	_process_touch();
	OS_Switch::get_singleton()->process_joypads();
	Input::get_singleton()->flush_buffered_events();
}
