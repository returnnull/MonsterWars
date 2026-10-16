/**************************************************************************/
/*  audio_driver_switch.cpp                                               */
/**************************************************************************/

#include "audio_driver_switch.h"

#include "core/config/project_settings.h"
#include "core/os/os.h"

#include <malloc.h>
#include <string.h>

static const AudioRendererConfig audren_config = {
	.output_rate = AudioRendererOutputRate_48kHz,
	.num_voices = 4,
	.num_effects = 0,
	.num_sinks = 1,
	.num_mix_objs = 1,
	.num_mix_buffers = 2,
};

Error AudioDriverSwitch::init() {
	// audren always runs at 48 kHz; mixing at the same rate avoids resampling.
	mix_rate = 48000;
	channels = 2;
	int latency = GLOBAL_GET("audio/driver/output_latency");
	buffer_size = closest_power_of_2(MAX(latency, 10) * mix_rate / 1000);
	buffer_size = CLAMP(buffer_size, 256u, 4096u);

	samples_in.resize(buffer_size * channels);
	samples_out.resize(buffer_size * channels);

	Result res = audrenInitialize(&audren_config);
	if (R_FAILED(res)) {
		ERR_PRINT(vformat("audrenInitialize failed: 0x%x", res));
		return ERR_CANT_OPEN;
	}
	res = audrvCreate(&audren_driver, &audren_config, channels);
	if (R_FAILED(res)) {
		audrenExit();
		ERR_PRINT(vformat("audrvCreate failed: 0x%x", res));
		return ERR_CANT_OPEN;
	}

	audren_buffer_size = sizeof(int16_t) * buffer_size * channels;
	audren_pool_size = ((audren_buffer_size * 2) + 0xFFF) & ~0xFFF;
	audren_pool_ptr = memalign(0x1000, audren_pool_size);
	memset(audren_pool_ptr, 0, audren_pool_size);
	armDCacheFlush(audren_pool_ptr, audren_pool_size);

	for (int i = 0; i < 2; i++) {
		memset(&audren_buffers[i], 0, sizeof(AudioDriverWaveBuf));
		audren_buffers[i].data_raw = audren_pool_ptr;
		audren_buffers[i].size = audren_pool_size;
		audren_buffers[i].start_sample_offset = i * buffer_size;
		audren_buffers[i].end_sample_offset = audren_buffers[i].start_sample_offset + buffer_size;
	}

	int mpid = audrvMemPoolAdd(&audren_driver, audren_pool_ptr, audren_pool_size);
	audrvMemPoolAttach(&audren_driver, mpid);

	static const u8 sink_channels[] = { 0, 1 };
	audrvDeviceSinkAdd(&audren_driver, AUDREN_DEFAULT_DEVICE_NAME, 2, sink_channels);

	audrvUpdate(&audren_driver);
	res = audrenStartAudioRenderer();
	if (R_FAILED(res)) {
		ERR_PRINT(vformat("audrenStartAudioRenderer failed: 0x%x", res));
	}

	audrvVoiceInit(&audren_driver, 0, channels, PcmFormat_Int16, mix_rate);
	audrvVoiceSetDestinationMix(&audren_driver, 0, AUDREN_FINAL_MIX_ID);
	audrvVoiceSetMixFactor(&audren_driver, 0, 1.0f, 0, 0);
	audrvVoiceSetMixFactor(&audren_driver, 0, 0.0f, 0, 1);
	audrvVoiceSetMixFactor(&audren_driver, 0, 0.0f, 1, 0);
	audrvVoiceSetMixFactor(&audren_driver, 0, 1.0f, 1, 1);
	audrvVoiceStart(&audren_driver, 0);

	audren_ready = true;
	exit_thread.clear();
	thread.start(AudioDriverSwitch::thread_func, this);
	return OK;
}

void AudioDriverSwitch::thread_func(void *p_udata) {
	AudioDriverSwitch *ad = static_cast<AudioDriverSwitch *>(p_udata);
	const int total = ad->buffer_size * ad->channels;
	int next = 0;

	while (!ad->exit_thread.is_set()) {
		AudioDriverWaveBuf &wb = ad->audren_buffers[next];
		if (wb.state != AudioDriverWaveBufState_Free && wb.state != AudioDriverWaveBufState_Done) {
			// Both buffers are queued; wait for the renderer to consume one.
			audrvUpdate(&ad->audren_driver);
			audrenWaitFrame();
			continue;
		}

		ad->lock();
		if (ad->active.is_set()) {
			ad->audio_server_process(ad->buffer_size, ad->samples_in.ptrw());
			for (int i = 0; i < total; i++) {
				ad->samples_out.write[i] = ad->samples_in[i] >> 16;
			}
		} else {
			memset(ad->samples_out.ptrw(), 0, total * sizeof(int16_t));
		}
		ad->unlock();

		uint8_t *ptr = (uint8_t *)ad->audren_pool_ptr + next * ad->audren_buffer_size;
		memcpy(ptr, ad->samples_out.ptr(), ad->audren_buffer_size);
		armDCacheFlush(ptr, ad->audren_buffer_size);
		audrvVoiceAddWaveBuf(&ad->audren_driver, 0, &wb);
		if (!audrvVoiceIsPlaying(&ad->audren_driver, 0)) {
			audrvVoiceStart(&ad->audren_driver, 0);
		}
		audrvUpdate(&ad->audren_driver);
		next = 1 - next;
	}
}

void AudioDriverSwitch::start() {
	active.set();
}

int AudioDriverSwitch::get_mix_rate() const {
	return mix_rate;
}

AudioDriver::SpeakerMode AudioDriverSwitch::get_speaker_mode() const {
	return SPEAKER_MODE_STEREO;
}

void AudioDriverSwitch::lock() {
	mutex.lock();
}

void AudioDriverSwitch::unlock() {
	mutex.unlock();
}

void AudioDriverSwitch::finish() {
	if (!audren_ready) {
		return;
	}
	exit_thread.set();
	if (thread.is_started()) {
		thread.wait_to_finish();
	}
	audrvClose(&audren_driver);
	audrenExit();
	free(audren_pool_ptr);
	audren_pool_ptr = nullptr;
	audren_ready = false;
}
