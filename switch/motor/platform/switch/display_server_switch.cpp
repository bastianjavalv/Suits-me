#include "display_server_switch.h"

#include "core/input/input.h"
#include "nx_wrap.h"

#include <cstdio>

#if defined(GLES3_ENABLED)
#include "drivers/gles3/rasterizer_gles3.h"
#endif

Vector<String> DisplayServerSwitch::get_rendering_drivers_func() {
	Vector<String> drivers;
	drivers.push_back("opengl3");
	return drivers;
}

DisplayServer *DisplayServerSwitch::create_func(const String &p_rendering_driver, DisplayServerEnums::WindowMode p_mode, DisplayServerEnums::VSyncMode p_vsync_mode, uint32_t p_flags, const Vector2i *p_position, const Vector2i &p_resolution, int p_screen, DisplayServerEnums::Context p_context, int64_t p_parent_window, Error &r_error) {
	DisplayServer *ds = memnew(DisplayServerSwitch(p_rendering_driver, p_vsync_mode, r_error));
	if (r_error != OK) {
		memdelete(ds);
		return nullptr;
	}
	return ds;
}

void DisplayServerSwitch::register_switch_driver() {
	register_create_function("switch", create_func, get_rendering_drivers_func);
}

bool DisplayServerSwitch::has_feature(DisplayServerEnums::Feature p_feature) const {
	switch (p_feature) {
		case DisplayServerEnums::FEATURE_TOUCHSCREEN:
		case DisplayServerEnums::FEATURE_VIRTUAL_KEYBOARD:
			return true;
		default:
			return false;
	}
}

Error DisplayServerSwitch::_init_egl() {
	egl_display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
	ERR_FAIL_COND_V_MSG(egl_display == EGL_NO_DISPLAY, ERR_UNAVAILABLE, vformat("eglGetDisplay failed: 0x%x", eglGetError()));
	ERR_FAIL_COND_V_MSG(!eglInitialize(egl_display, nullptr, nullptr), ERR_UNAVAILABLE, vformat("eglInitialize failed: 0x%x", eglGetError()));
	ERR_FAIL_COND_V_MSG(!eglBindAPI(EGL_OPENGL_ES_API), ERR_UNAVAILABLE, vformat("eglBindAPI failed: 0x%x", eglGetError()));

	// Prefer a config that explicitly advertises ES3; fall back to the driver default, which is what
	// the Godot 3 port used and Mesa accepts for ES3 contexts.
	EGLConfig config = nullptr;
	EGLint num_configs = 0;
	const EGLint attribs_es3[] = {
		EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT,
		EGL_RED_SIZE, 8,
		EGL_GREEN_SIZE, 8,
		EGL_BLUE_SIZE, 8,
		EGL_ALPHA_SIZE, 8,
		EGL_DEPTH_SIZE, 24,
		EGL_STENCIL_SIZE, 8,
		EGL_NONE
	};
	const EGLint attribs_default[] = {
		EGL_RED_SIZE, 8,
		EGL_GREEN_SIZE, 8,
		EGL_BLUE_SIZE, 8,
		EGL_ALPHA_SIZE, 8,
		EGL_DEPTH_SIZE, 24,
		EGL_STENCIL_SIZE, 8,
		EGL_NONE
	};
	eglChooseConfig(egl_display, attribs_es3, &config, 1, &num_configs);
	if (num_configs == 0) {
		print_verbose("Switch EGL: no ES3-tagged config, retrying with default attributes.");
		eglChooseConfig(egl_display, attribs_default, &config, 1, &num_configs);
	}
	ERR_FAIL_COND_V_MSG(num_configs == 0, ERR_UNAVAILABLE, vformat("No EGL config found: 0x%x", eglGetError()));
	egl_config = config;

	is_docked = nx::docked();
	Error err = _create_surface(_size_for_mode(is_docked));
	if (err != OK && is_docked) {
		print_line("Switch: 1920x1080 surface failed, falling back to 1280x720.");
		err = _create_surface(_size_for_mode(false));
	}
	ERR_FAIL_COND_V(err != OK, err);

	const EGLint context_attribs[] = { EGL_CONTEXT_CLIENT_VERSION, 3, EGL_NONE };
	egl_context = eglCreateContext(egl_display, config, EGL_NO_CONTEXT, context_attribs);
	ERR_FAIL_COND_V_MSG(egl_context == EGL_NO_CONTEXT, ERR_UNAVAILABLE, vformat("eglCreateContext failed: 0x%x", eglGetError()));

	ERR_FAIL_COND_V_MSG(!eglMakeCurrent(egl_display, egl_surface, egl_surface, egl_context), ERR_UNAVAILABLE, vformat("eglMakeCurrent failed: 0x%x", eglGetError()));
	return OK;
}

Size2i DisplayServerSwitch::_size_for_mode(bool p_docked) {
	return p_docked ? Size2i(nx::DOCKED_WIDTH, nx::DOCKED_HEIGHT) : Size2i(nx::HANDHELD_WIDTH, nx::HANDHELD_HEIGHT);
}

// Sizes the native window and creates the EGL surface on it. The window can only change size while no
// surface holds buffers on it, so any previous surface must already be destroyed.
Error DisplayServerSwitch::_create_surface(const Size2i &p_size) {
	void *win = nx::default_window(p_size.width, p_size.height);
	egl_surface = eglCreateWindowSurface(egl_display, egl_config, (EGLNativeWindowType)win, nullptr);
	ERR_FAIL_COND_V_MSG(egl_surface == EGL_NO_SURFACE, ERR_UNAVAILABLE, vformat("eglCreateWindowSurface(%dx%d) failed: 0x%x", p_size.width, p_size.height, eglGetError()));
	window_size = p_size;
	print_line(vformat("Switch: window %dx%d (%s).", p_size.width, p_size.height, is_docked ? "docked" : "handheld"));
	return OK;
}

// Dock/undock: unbind the context (it keeps every GL object), replace the surface with one of the new size
// and tell the root Window, which resizes its viewport like after any desktop window resize.
void DisplayServerSwitch::_resize_surface(const Size2i &p_size) {
	const Size2i previous = window_size;
	eglMakeCurrent(egl_display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
	eglDestroySurface(egl_display, egl_surface);
	egl_surface = EGL_NO_SURFACE;

	if (_create_surface(p_size) != OK) {
		ERR_FAIL_COND_MSG(_create_surface(previous) != OK, "Switch: could not recreate the EGL surface.");
	}
	ERR_FAIL_COND_MSG(!eglMakeCurrent(egl_display, egl_surface, egl_surface, egl_context), vformat("eglMakeCurrent failed: 0x%x", eglGetError()));
	window_set_vsync_mode(vsync_mode); // The swap interval belongs to the surface.

	if (window_size != previous && rect_changed_callback.is_valid()) {
		rect_changed_callback.call(Rect2i(Point2i(), window_size));
	}
}

void DisplayServerSwitch::_destroy_egl() {
	if (egl_display == EGL_NO_DISPLAY) {
		return;
	}
	eglMakeCurrent(egl_display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
	if (egl_context != EGL_NO_CONTEXT) {
		eglDestroyContext(egl_display, egl_context);
		egl_context = EGL_NO_CONTEXT;
	}
	if (egl_surface != EGL_NO_SURFACE) {
		eglDestroySurface(egl_display, egl_surface);
		egl_surface = EGL_NO_SURFACE;
	}
	eglTerminate(egl_display);
	egl_display = EGL_NO_DISPLAY;
}

void DisplayServerSwitch::window_set_vsync_mode(DisplayServerEnums::VSyncMode p_vsync_mode, DisplayServerEnums::WindowID p_window) {
	vsync_mode = p_vsync_mode;
	if (egl_display != EGL_NO_DISPLAY) {
		eglSwapInterval(egl_display, p_vsync_mode == DisplayServerEnums::VSYNC_DISABLED ? 0 : 1);
	}
}

void DisplayServerSwitch::swap_buffers() {
	eglSwapBuffers(egl_display, egl_surface);

	// Shader compiles and texture uploads happen inside draw calls, so they surface as long frames.
	static uint64_t last_ms = 0;
	uint64_t now = nx::millis();
	if (last_ms != 0 && now - last_ms > 100) {
		printf("PROFILE: slow frame %llu ms\n", (unsigned long long)(now - last_ms));
	}
	last_ms = now;
}

// Only records the request; process_events() opens the keyboard once the screen has been presented for
// a few frames (see KEYBOARD_DELAY_FRAMES).
void DisplayServerSwitch::virtual_keyboard_show(const String &p_existing_text, const Rect2 &p_screen_rect, DisplayServerEnums::VirtualKeyboardType p_type, int p_max_length, int p_cursor_start, int p_cursor_end) {
	keyboard_requested = true;
	keyboard_wait_frames = KEYBOARD_DELAY_FRAMES;
	keyboard_existing_text = p_existing_text;
	keyboard_max_length = (p_max_length > 0 && p_max_length <= 500) ? p_max_length : 500;
}

// The field lost focus before the keyboard opened: forget the request.
void DisplayServerSwitch::virtual_keyboard_hide() {
	keyboard_requested = false;
}

static Ref<InputEventKey> _key_event(Key p_keycode, char32_t p_unicode, bool p_ctrl, bool p_pressed) {
	Ref<InputEventKey> ev;
	ev.instantiate();
	ev->set_keycode(p_keycode);
	ev->set_physical_keycode(p_keycode);
	ev->set_unicode(p_unicode);
	ev->set_ctrl_pressed(p_ctrl);
	ev->set_pressed(p_pressed);
	return ev;
}

// Replace the field's contents: select all, then either delete (empty result) or type the new text.
void DisplayServerSwitch::_inject_keyboard_text(const String &p_text) {
	Input *input = Input::get_singleton();
	input->parse_input_event(_key_event(Key::A, 'a', true, true));
	input->parse_input_event(_key_event(Key::A, 'a', true, false));
	if (p_text.is_empty()) {
		input->parse_input_event(_key_event(Key::BACKSPACE, 0, false, true));
		input->parse_input_event(_key_event(Key::BACKSPACE, 0, false, false));
		return;
	}
	for (int i = 0; i < p_text.length(); i++) {
		char32_t c = p_text[i];
		input->parse_input_event(_key_event(Key::NONE, c, false, true));
		input->parse_input_event(_key_event(Key::NONE, c, false, false));
	}
}

void DisplayServerSwitch::process_events() {
	const bool now_docked = nx::docked();
	if (now_docked != is_docked) {
		is_docked = now_docked;
		_resize_surface(_size_for_mode(is_docked));
	}

	if (keyboard_requested && --keyboard_wait_frames <= 0) {
		keyboard_requested = false;
		char out[2048];
		CharString initial = keyboard_existing_text.utf8();
		// Blocks while the applet is up; a cancel leaves the field untouched.
		if (nx::keyboard_show(initial.get_data(), "", keyboard_max_length, out, sizeof(out))) {
			pending_keyboard_text = String::utf8(out);
			has_pending_keyboard_text = true;
		}
	}
	if (has_pending_keyboard_text) {
		has_pending_keyboard_text = false;
		_inject_keyboard_text(pending_keyboard_text);
		pending_keyboard_text = String();
	}

	nx::TouchPoint points[10];
	int count = nx::touch_poll(points, 10);
	Input *input = Input::get_singleton();

	// The touch panel always reports 1280x720 coordinates; map them to the window.
	const Vector2 touch_scale(window_size.width / (float)nx::HANDHELD_WIDTH, window_size.height / (float)nx::HANDHELD_HEIGHT);
	HashMap<uint32_t, Vector2> now;
	for (int i = 0; i < count; i++) {
		Vector2 pos = Vector2(points[i].x, points[i].y) * touch_scale;
		now[points[i].id] = pos;

		if (!touches.has(points[i].id)) {
			Ref<InputEventScreenTouch> ev;
			ev.instantiate();
			ev->set_index(points[i].id);
			ev->set_position(pos);
			ev->set_pressed(true);
			input->parse_input_event(ev);
		} else if (touches[points[i].id] != pos) {
			Ref<InputEventScreenDrag> ev;
			ev.instantiate();
			ev->set_index(points[i].id);
			ev->set_position(pos);
			ev->set_relative(pos - touches[points[i].id]);
			ev->set_relative_screen_position(pos - touches[points[i].id]);
			input->parse_input_event(ev);
		}
	}
	for (const KeyValue<uint32_t, Vector2> &kv : touches) {
		if (!now.has(kv.key)) {
			Ref<InputEventScreenTouch> ev;
			ev.instantiate();
			ev->set_index(kv.key);
			ev->set_position(kv.value);
			ev->set_pressed(false);
			input->parse_input_event(ev);
		}
	}
	touches = now;
	input->flush_buffered_events();
}

DisplayServerSwitch::DisplayServerSwitch(const String &p_rendering_driver, DisplayServerEnums::VSyncMode p_vsync_mode, Error &r_error) {
	rendering_driver = p_rendering_driver;

	r_error = _init_egl();
	if (r_error != OK) {
		_destroy_egl();
		return;
	}
	window_set_vsync_mode(p_vsync_mode);

	nx::gl_selftest(); // Logs texture/swizzle sanity results to the SD log.

	nx::present_test(egl_display, egl_surface, window_size.width, window_size.height);

#if defined(GLES3_ENABLED)
	if (rendering_driver == "opengl3") {
		RasterizerGLES3::make_current(false);
	}
#endif
	r_error = OK;
}

DisplayServerSwitch::~DisplayServerSwitch() {
	_destroy_egl();
}
