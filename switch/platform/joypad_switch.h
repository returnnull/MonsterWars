/**************************************************************************/
/*  joypad_switch.h                                                       */
/**************************************************************************/

#ifndef JOYPAD_SWITCH_H
#define JOYPAD_SWITCH_H

#include "switch_wrapper.h"

#include "core/input/input.h"

// Reads the Npad controllers through libnx and feeds them to Godot as
// joypads 0-3 (player 1 also gets the console in handheld mode).
class JoypadSwitch {
	static const int MAX_PADS = 4;

	struct Pad {
		PadState state;
		bool connected = false;
		u32 style = 0;
		u64 buttons = 0;
		HidVibrationDeviceHandle vib_handles[2];
		int vib_count = 0;
		u32 vib_style = 0;
		uint64_t vib_timestamp = 0;
		uint64_t vib_end_usec = 0;
		bool vibrating = false;
	};

	Input *input = nullptr;
	Pad pads[MAX_PADS];

	void _update_pad(int p_idx);
	void _update_vibration(int p_idx);
	void _send_vibration(int p_idx, float p_weak, float p_strong);

public:
	void process();

	JoypadSwitch(Input *p_input);
	~JoypadSwitch();
};

#endif // JOYPAD_SWITCH_H
