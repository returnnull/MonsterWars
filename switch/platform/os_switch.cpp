/**************************************************************************/
/*  os_switch.cpp                                                         */
/**************************************************************************/

#include "os_switch.h"

#include "display_server_switch.h"
#include "switch_wrapper.h"

#include "main/main.h"

#include <stdio.h>

OS_Switch::OS_Switch() {
	AudioDriverManager::add_driver(&audio_driver);
	DisplayServerSwitch::register_switch_driver();
}

void OS_Switch::initialize() {
	OS_Unix::initialize_core();
}

void OS_Switch::initialize_joypads() {
	joypad = memnew(JoypadSwitch(Input::get_singleton()));
}

void OS_Switch::set_main_loop(MainLoop *p_main_loop) {
	main_loop = p_main_loop;
}

void OS_Switch::delete_main_loop() {
	if (main_loop) {
		memdelete(main_loop);
	}
	main_loop = nullptr;
}

void OS_Switch::finalize() {
	delete_main_loop();
	if (joypad) {
		memdelete(joypad);
		joypad = nullptr;
	}
}

bool OS_Switch::_check_internal_feature_support(const String &p_feature) {
	return p_feature == "switch" || p_feature == "horizon";
}

void OS_Switch::process_joypads() {
	if (joypad) {
		joypad->process();
	}
}

void OS_Switch::run() {
	if (!main_loop) {
		return;
	}

	main_loop->initialize();

	// appletMainLoop() returns false when the HOME menu closes the game.
	while (appletMainLoop()) {
		DisplayServer::get_singleton()->process_events();
		if (Main::iteration()) {
			break;
		}
	}

	main_loop->finalize();
}

String OS_Switch::get_version() const {
	SetSysFirmwareVersion fw;
	if (R_SUCCEEDED(setsysInitialize())) {
		Result res = setsysGetFirmwareVersion(&fw);
		setsysExit();
		if (R_SUCCEEDED(res)) {
			return String(fw.display_version);
		}
	}
	return "";
}

String OS_Switch::get_locale() const {
	String locale = "en";
	u64 code = 0;
	if (R_SUCCEEDED(setInitialize())) {
		if (R_SUCCEEDED(setGetSystemLanguage(&code))) {
			// The language code is a NUL-padded ASCII string such as "da" or "en-US".
			char buf[9] = {};
			memcpy(buf, &code, 8);
			locale = String(buf).replace("-", "_");
		}
		setExit();
	}
	return locale;
}

Dictionary OS_Switch::get_memory_info() const {
	Dictionary meminfo;
	u64 total = 0;
	u64 used = 0;
	svcGetInfo(&total, InfoType_TotalMemorySize, CUR_PROCESS_HANDLE, 0);
	svcGetInfo(&used, InfoType_UsedMemorySize, CUR_PROCESS_HANDLE, 0);
	meminfo["physical"] = (int64_t)total;
	meminfo["free"] = (int64_t)(total - used);
	meminfo["available"] = (int64_t)(total - used);
	meminfo["stack"] = -1;
	return meminfo;
}

void OS_Switch::alert(const String &p_alert, const String &p_title) {
	printf("%s: %s\n", p_title.utf8().get_data(), p_alert.utf8().get_data());
	fflush(stdout);

	ErrorApplicationConfig config;
	if (R_SUCCEEDED(errorApplicationCreate(&config, p_title.utf8().get_data(), p_alert.utf8().get_data()))) {
		errorApplicationShow(&config);
	}
}

Error OS_Switch::execute(const String &p_path, const List<String> &p_arguments, String *r_pipe, int *r_exitcode, bool read_stderr, Mutex *p_pipe_mutex, bool p_open_console) {
	return ERR_UNAVAILABLE;
}

Dictionary OS_Switch::execute_with_pipe(const String &p_path, const List<String> &p_arguments, bool p_blocking) {
	return Dictionary();
}

Error OS_Switch::create_process(const String &p_path, const List<String> &p_arguments, ProcessID *r_child_id, bool p_open_console) {
	return ERR_UNAVAILABLE;
}

Error OS_Switch::kill(const ProcessID &p_pid) {
	return ERR_UNAVAILABLE;
}
