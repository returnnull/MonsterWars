/**************************************************************************/
/*  joypad_switch.cpp                                                     */
/**************************************************************************/

#include "joypad_switch.h"

#include "core/os/os.h"

// Godot button for each Npad button on a full controller (Pro Controller,
// Joy-Con pair, handheld). Godot's face buttons are positional (A = bottom),
// so Nintendo's B (bottom) is JoyButton::A, matching the game's hints.
struct ButtonMap {
	u64 npad;
	JoyButton button;
};

static const ButtonMap full_map[] = {
	{ HidNpadButton_B, JoyButton::A },
	{ HidNpadButton_A, JoyButton::B },
	{ HidNpadButton_Y, JoyButton::X },
	{ HidNpadButton_X, JoyButton::Y },
	{ HidNpadButton_Minus, JoyButton::BACK },
	{ HidNpadButton_Plus, JoyButton::START },
	{ HidNpadButton_StickL, JoyButton::LEFT_STICK },
	{ HidNpadButton_StickR, JoyButton::RIGHT_STICK },
	{ HidNpadButton_L, JoyButton::LEFT_SHOULDER },
	{ HidNpadButton_R, JoyButton::RIGHT_SHOULDER },
	{ HidNpadButton_Up, JoyButton::DPAD_UP },
	{ HidNpadButton_Down, JoyButton::DPAD_DOWN },
	{ HidNpadButton_Left, JoyButton::DPAD_LEFT },
	{ HidNpadButton_Right, JoyButton::DPAD_RIGHT },
};

// A single Joy-Con held sideways: the four buttons become the face buttons
// and SL/SR the shoulders, laid out by position like a full controller.
static const ButtonMap left_joy_map[] = {
	{ HidNpadButton_Left, JoyButton::A },
	{ HidNpadButton_Down, JoyButton::B },
	{ HidNpadButton_Up, JoyButton::X },
	{ HidNpadButton_Right, JoyButton::Y },
	{ HidNpadButton_LeftSL, JoyButton::LEFT_SHOULDER },
	{ HidNpadButton_LeftSR, JoyButton::RIGHT_SHOULDER },
	{ HidNpadButton_Minus, JoyButton::START },
	{ HidNpadButton_StickL, JoyButton::LEFT_STICK },
};

static const ButtonMap right_joy_map[] = {
	{ HidNpadButton_A, JoyButton::A },
	{ HidNpadButton_X, JoyButton::B },
	{ HidNpadButton_B, JoyButton::X },
	{ HidNpadButton_Y, JoyButton::Y },
	{ HidNpadButton_RightSL, JoyButton::LEFT_SHOULDER },
	{ HidNpadButton_RightSR, JoyButton::RIGHT_SHOULDER },
	{ HidNpadButton_Plus, JoyButton::START },
	{ HidNpadButton_StickR, JoyButton::LEFT_STICK },
};

enum PadKind {
	PAD_FULL,
	PAD_LEFT_JOY,
	PAD_RIGHT_JOY,
};

static PadKind _pad_kind(u32 p_style) {
	if (p_style & (HidNpadStyleTag_NpadJoyDual | HidNpadStyleTag_NpadFullKey | HidNpadStyleTag_NpadHandheld)) {
		return PAD_FULL;
	}
	if (p_style & HidNpadStyleTag_NpadJoyLeft) {
		return PAD_LEFT_JOY;
	}
	if (p_style & HidNpadStyleTag_NpadJoyRight) {
		return PAD_RIGHT_JOY;
	}
	return PAD_FULL;
}

static float _stick(s32 p_value) {
	return CLAMP(p_value / 32767.0f, -1.0f, 1.0f);
}

JoypadSwitch::JoypadSwitch(Input *p_input) {
	input = p_input;

	padConfigureInput(MAX_PADS, HidNpadStyleSet_NpadStandard);
	// Single Joy-Cons are held sideways, so two pairs give four players.
	hidSetNpadJoyHoldType(HidNpadJoyHoldType_Horizontal);

	padInitialize(&pads[0].state, HidNpadIdType_No1, HidNpadIdType_Handheld);
	padInitialize(&pads[1].state, HidNpadIdType_No2);
	padInitialize(&pads[2].state, HidNpadIdType_No3);
	padInitialize(&pads[3].state, HidNpadIdType_No4);
}

JoypadSwitch::~JoypadSwitch() {
	for (int i = 0; i < MAX_PADS; i++) {
		if (pads[i].vibrating) {
			_send_vibration(i, 0, 0);
		}
	}
}

void JoypadSwitch::process() {
	for (int i = 0; i < MAX_PADS; i++) {
		_update_pad(i);
	}
}

void JoypadSwitch::_update_pad(int p_idx) {
	Pad &pad = pads[p_idx];
	padUpdate(&pad.state);

	bool connected = padIsConnected(&pad.state);
	u32 style = padGetStyleSet(&pad.state);

	if (connected != pad.connected || (connected && style != pad.style)) {
		if (pad.connected) {
			// Release everything held on the old controller.
			input->joy_connection_changed(p_idx, false, "");
		}
		pad.connected = connected;
		pad.style = style;
		pad.buttons = 0;
		pad.vib_style = 0;
		if (connected) {
			const char *name = "Nintendo Switch Controller";
			PadKind kind = _pad_kind(style);
			if (kind == PAD_LEFT_JOY) {
				name = "Joy-Con (L)";
			} else if (kind == PAD_RIGHT_JOY) {
				name = "Joy-Con (R)";
			} else if (style & HidNpadStyleTag_NpadHandheld) {
				name = "Nintendo Switch Handheld";
			}
			input->joy_connection_changed(p_idx, true, name, "__SWITCH_NPAD__");
		}
	}

	if (!connected) {
		return;
	}

	PadKind kind = _pad_kind(style);
	u64 buttons = padGetButtons(&pad.state);
	u64 changed = buttons ^ pad.buttons;

	const ButtonMap *map = full_map;
	int map_size = sizeof(full_map) / sizeof(full_map[0]);
	if (kind == PAD_LEFT_JOY) {
		map = left_joy_map;
		map_size = sizeof(left_joy_map) / sizeof(left_joy_map[0]);
	} else if (kind == PAD_RIGHT_JOY) {
		map = right_joy_map;
		map_size = sizeof(right_joy_map) / sizeof(right_joy_map[0]);
	}

	if (changed) {
		for (int b = 0; b < map_size; b++) {
			if (changed & map[b].npad) {
				input->joy_button(p_idx, map[b].button, (buttons & map[b].npad) != 0);
			}
		}
	}
	pad.buttons = buttons;

	// Godot's Y axis points down, Horizon's points up.
	if (kind == PAD_FULL) {
		HidAnalogStickState l = padGetStickPos(&pad.state, 0);
		HidAnalogStickState r = padGetStickPos(&pad.state, 1);
		input->joy_axis(p_idx, JoyAxis::LEFT_X, _stick(l.x));
		input->joy_axis(p_idx, JoyAxis::LEFT_Y, -_stick(l.y));
		input->joy_axis(p_idx, JoyAxis::RIGHT_X, _stick(r.x));
		input->joy_axis(p_idx, JoyAxis::RIGHT_Y, -_stick(r.y));
		input->joy_axis(p_idx, JoyAxis::TRIGGER_LEFT, (buttons & HidNpadButton_ZL) ? 1.0f : 0.0f);
		input->joy_axis(p_idx, JoyAxis::TRIGGER_RIGHT, (buttons & HidNpadButton_ZR) ? 1.0f : 0.0f);
	} else if (kind == PAD_LEFT_JOY) {
		// Rotated a quarter turn counter-clockwise when held sideways.
		HidAnalogStickState s = padGetStickPos(&pad.state, 0);
		input->joy_axis(p_idx, JoyAxis::LEFT_X, -_stick(s.y));
		input->joy_axis(p_idx, JoyAxis::LEFT_Y, -_stick(s.x));
	} else {
		// Rotated a quarter turn clockwise when held sideways.
		HidAnalogStickState s = padGetStickPos(&pad.state, 1);
		input->joy_axis(p_idx, JoyAxis::LEFT_X, _stick(s.y));
		input->joy_axis(p_idx, JoyAxis::LEFT_Y, _stick(s.x));
	}

	_update_vibration(p_idx);
}

void JoypadSwitch::_send_vibration(int p_idx, float p_weak, float p_strong) {
	Pad &pad = pads[p_idx];
	if (pad.vib_style != pad.style) {
		pad.vib_style = pad.style;
		pad.vib_count = 0;
		HidNpadIdType id = (HidNpadIdType)p_idx;
		u32 style = pad.style;
		if (p_idx == 0 && (style & HidNpadStyleTag_NpadHandheld)) {
			id = HidNpadIdType_Handheld;
		}
		HidNpadStyleTag tag = HidNpadStyleTag_NpadFullKey;
		int count = 2;
		if (style & HidNpadStyleTag_NpadHandheld) {
			tag = HidNpadStyleTag_NpadHandheld;
		} else if (style & HidNpadStyleTag_NpadJoyDual) {
			tag = HidNpadStyleTag_NpadJoyDual;
		} else if (style & HidNpadStyleTag_NpadJoyLeft) {
			tag = HidNpadStyleTag_NpadJoyLeft;
			count = 1;
		} else if (style & HidNpadStyleTag_NpadJoyRight) {
			tag = HidNpadStyleTag_NpadJoyRight;
			count = 1;
		}
		if (R_SUCCEEDED(hidInitializeVibrationDevices(pad.vib_handles, count, id, tag))) {
			pad.vib_count = count;
		}
	}
	if (pad.vib_count == 0) {
		return;
	}

	HidVibrationValue values[2];
	for (int i = 0; i < pad.vib_count; i++) {
		values[i].amp_low = CLAMP(p_strong, 0.0f, 1.0f);
		values[i].freq_low = 160.0f;
		values[i].amp_high = CLAMP(p_weak, 0.0f, 1.0f);
		values[i].freq_high = 320.0f;
	}
	hidSendVibrationValues(pad.vib_handles, values, pad.vib_count);
}

void JoypadSwitch::_update_vibration(int p_idx) {
	Pad &pad = pads[p_idx];
	uint64_t timestamp = input->get_joy_vibration_timestamp(p_idx);
	uint64_t now = OS::get_singleton()->get_ticks_usec();

	if (timestamp != pad.vib_timestamp) {
		pad.vib_timestamp = timestamp;
		Vector2 strength = input->get_joy_vibration_strength(p_idx);
		float duration = input->get_joy_vibration_duration(p_idx);
		if (strength.x <= 0 && strength.y <= 0) {
			_send_vibration(p_idx, 0, 0);
			pad.vibrating = false;
		} else {
			_send_vibration(p_idx, strength.x, strength.y);
			pad.vibrating = true;
			pad.vib_end_usec = duration > 0 ? now + (uint64_t)(duration * 1000000.0) : 0;
		}
	} else if (pad.vibrating && pad.vib_end_usec != 0 && now >= pad.vib_end_usec) {
		_send_vibration(p_idx, 0, 0);
		pad.vibrating = false;
	}
}
