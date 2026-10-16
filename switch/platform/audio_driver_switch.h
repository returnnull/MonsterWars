/**************************************************************************/
/*  audio_driver_switch.h                                                 */
/**************************************************************************/

#ifndef AUDIO_DRIVER_SWITCH_H
#define AUDIO_DRIVER_SWITCH_H

#include "switch_wrapper.h"

#include "core/os/mutex.h"
#include "core/os/thread.h"
#include "core/templates/safe_refcount.h"
#include "servers/audio_server.h"

// Plays Godot's mix through the audio renderer service (audren).
class AudioDriverSwitch : public AudioDriver {
	Thread thread;
	Mutex mutex;

	LibnxAudioDriver audren_driver;
	AudioDriverWaveBuf audren_buffers[2];
	void *audren_pool_ptr = nullptr;
	size_t audren_pool_size = 0;
	size_t audren_buffer_size = 0;
	bool audren_ready = false;

	Vector<int32_t> samples_in;
	Vector<int16_t> samples_out;

	static void thread_func(void *p_udata);

	unsigned int mix_rate = 48000;
	unsigned int buffer_size = 0;
	int channels = 2;

	SafeFlag active;
	SafeFlag exit_thread;

public:
	virtual const char *get_name() const override { return "Switch"; }

	virtual Error init() override;
	virtual void start() override;
	virtual int get_mix_rate() const override;
	virtual SpeakerMode get_speaker_mode() const override;
	virtual void lock() override;
	virtual void unlock() override;
	virtual void finish() override;

	AudioDriverSwitch() {}
	~AudioDriverSwitch() {}
};

#endif // AUDIO_DRIVER_SWITCH_H
