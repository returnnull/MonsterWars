import os
import sys
from typing import TYPE_CHECKING

from methods import print_error

if TYPE_CHECKING:
    from SCons.Script.SConscript import SConsEnvironment


def get_name():
    return "Switch"


def can_build():
    dkp = os.environ.get("DEVKITPRO")
    if not dkp:
        return False
    return os.path.exists(dkp + "/devkitA64") and os.path.exists(dkp + "/libnx")


def get_tools(env: "SConsEnvironment"):
    return ["cc", "c++", "ar", "link", "textfile", "zip"]


def get_opts():
    return []


def get_doc_classes():
    return []


def get_doc_path():
    return "doc_classes"


def get_flags():
    return {
        "arch": "arm64",
        "target": "template_release",
        "vulkan": False,
        "opengl3": True,
        # Not available or not useful on Horizon.
        "module_mono_enabled": False,
        "module_raycast_enabled": False,
        "module_upnp_enabled": False,
        "module_webrtc_enabled": False,
        "module_websocket_enabled": False,
        "module_mbedtls_enabled": False,
        "module_enet_enabled": False,
        "module_multiplayer_enabled": False,
        "module_camera_enabled": False,
        "module_openxr_enabled": False,
        "module_theora_enabled": False,
        "module_text_server_adv_enabled": False,
        "module_text_server_fb_enabled": True,
        "brotli": False,
        "builtin_pcre2_with_jit": False,
        "disable_exceptions": True,
        "lto": "none",
    }


def configure(env: "SConsEnvironment"):
    if env["arch"] != "arm64":
        print_error("Switch only supports arch=arm64.")
        sys.exit(255)
    if env.editor_build:
        print_error("Only export templates can be built for Switch.")
        sys.exit(255)

    dkp = os.environ["DEVKITPRO"]
    env["ENV"]["DEVKITPRO"] = dkp
    path = "{0}/devkitA64/bin:{0}/portlibs/switch/bin:{0}/tools/bin:".format(dkp) + os.environ["PATH"]
    env["ENV"]["PATH"] = path
    os.environ["PATH"] = path

    env["CC"] = "aarch64-none-elf-gcc"
    env["CXX"] = "aarch64-none-elf-g++"
    env["LINK"] = "aarch64-none-elf-g++"
    env["AR"] = "aarch64-none-elf-ar"
    env["RANLIB"] = "aarch64-none-elf-ranlib"
    env["AS"] = "aarch64-none-elf-as"

    arch = ["-march=armv8-a+crc+crypto", "-mtune=cortex-a57", "-mtp=soft", "-fPIE"]
    env.Prepend(CCFLAGS=arch + ["-ffunction-sections", "-fdata-sections"])
    env.Append(CPPDEFINES=["__SWITCH__", "HORIZON_ENABLED", "UNIX_ENABLED", "EGL_STATIC", "NO_FCNTL", "UNIX_SOCKET_UNAVAILABLE", "_GNU_SOURCE", "GLES3_ENABLED"])
    env.Prepend(CPPPATH=["#platform/switch"])
    env.Append(CCFLAGS=["-isystem", dkp + "/portlibs/switch/include", "-isystem", dkp + "/libnx/include"])

    env.Append(LIBPATH=[dkp + "/portlibs/switch/lib", dkp + "/libnx/lib"])
    env.Append(LINKFLAGS=arch + ["-specs=" + dkp + "/libnx/switch.specs", "-Wl,--gc-sections"])
    env.Append(LIBS=["EGL", "glapi", "drm_nouveau", "nx", "m"])
