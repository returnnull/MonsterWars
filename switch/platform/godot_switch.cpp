/**************************************************************************/
/*  godot_switch.cpp                                                      */
/**************************************************************************/

#include "os_switch.h"
#include "switch_wrapper.h"

#include "main/main.h"

#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <unistd.h>

// Where stdout/stderr go when the game is not started through nxlink.
#define LOG_DIR "sdmc:/switch/kaiju-dawn"
#define LOG_FILE LOG_DIR "/log.txt"

// Godot's GDScript VM recurses deeply; the main thread from the homebrew
// loader is too small, so the engine runs on a thread with a bigger stack.
#define ENGINE_STACK_SIZE (8 * 1024 * 1024)

struct MainArgs {
	int argc;
	char **argv;
	const char *exe;
	int exit_code;
};

static void *engine_main(void *p_data) {
	MainArgs *args = static_cast<MainArgs *>(p_data);

	OS_Switch os;
	os.set_executable_path(args->exe);

	// The game pack is stored in the .nro's RomFS. Compatibility renderer
	// on Mesa's desktop OpenGL is the only renderer available on Horizon.
	Vector<CharString> extra;
	extra.push_back("--main-pack");
	extra.push_back("romfs:/game.pck");
	extra.push_back("--display-driver");
	extra.push_back("switch");
	extra.push_back("--rendering-driver");
	extra.push_back("opengl3");
	extra.push_back("--rendering-method");
	extra.push_back("gl_compatibility");
	extra.push_back("--audio-driver");
	extra.push_back("Switch");

	Vector<char *> argv;
	for (int i = 0; i < extra.size(); i++) {
		argv.push_back(extra.write[i].ptrw());
	}
	for (int i = 1; i < args->argc; i++) {
		argv.push_back(args->argv[i]);
	}

	Error err = Main::setup(args->exe, argv.size(), argv.ptrw());
	if (err != OK) {
		args->exit_code = err == ERR_HELP ? EXIT_SUCCESS : EXIT_FAILURE;
		return nullptr;
	}

	if (Main::start() == EXIT_SUCCESS) {
		os.run();
	} else {
		os.set_exit_code(EXIT_FAILURE);
	}
	Main::cleanup();

	args->exit_code = os.get_exit_code();
	return nullptr;
}

// Homebrew started from the album only gets a small slice of memory, which
// is not enough for the engine. Tell the player how to start it properly.
static bool check_applet_mode() {
	AppletType type = appletGetAppletType();
	if (type == AppletType_Application || type == AppletType_SystemApplication) {
		return true;
	}

	consoleInit(nullptr);
	printf("\n\n  Kaiju Dawn needs full RAM access.\n\n");
	printf("  Start it from hbmenu opened through a game:\n");
	printf("  hold R while starting any game, then pick Kaiju Dawn.\n");
	printf("  (Or install the .nsp forwarder.)\n\n");
	printf("  Press any button to exit.\n");
	consoleUpdate(nullptr);

	PadState pad;
	padConfigureInput(1, HidNpadStyleSet_NpadStandard);
	padInitializeDefault(&pad);
	while (appletMainLoop()) {
		padUpdate(&pad);
		if (padGetButtonsDown(&pad)) {
			break;
		}
		consoleUpdate(nullptr);
	}
	consoleExit(nullptr);
	return false;
}

int main(int argc, char *argv[]) {
	if (!check_applet_mode()) {
		return 0;
	}

	romfsInit();
	socketInitializeDefault();
	if (nxlinkStdio() < 0) {
		mkdir(LOG_DIR, 0777);
		freopen(LOG_FILE, "w", stdout);
		freopen(LOG_FILE, "a", stderr);
		setvbuf(stdout, nullptr, _IOLBF, 0);
		setvbuf(stderr, nullptr, _IONBF, 0);
	}

	// Installed as a title (.nsp) there is no argv[0].
	const char *exe = (argc > 0 && argv[0]) ? argv[0] : "sdmc:/switch/kaiju-dawn.nro";
	MainArgs args = { argc, argv, exe, EXIT_FAILURE };

	pthread_attr_t attr;
	pthread_attr_init(&attr);
	pthread_attr_setstacksize(&attr, ENGINE_STACK_SIZE);
	pthread_t thread;
	if (pthread_create(&thread, &attr, engine_main, &args) == 0) {
		pthread_join(thread, nullptr);
	} else {
		printf("Could not start the engine thread.\n");
	}
	pthread_attr_destroy(&attr);

	fflush(stdout);
	socketExit();
	romfsExit();
	return args.exit_code;
}
