# Kaiju Dawn on Nintendo Switch (homebrew)

This folder ports Godot 4.4.1 to the Switch with devkitPro/libnx and packs the
game as a homebrew `.nro`, plus the files for an installable `.nsp`.

It needs a Switch running custom firmware (Atmosphère). An official release
on an unmodified Switch needs Nintendo's developer program instead.

## What is in here

- `platform/`: the Switch platform for Godot (copied into the engine's
  `platform/switch` at build time).
  - Graphics: Mesa's desktop OpenGL 3.3 through EGL, so the game runs with
    Godot's Compatibility renderer at 1280x720 (the console scales it when docked).
  - Controllers: up to 4 players. Pro Controllers, Joy-Con pairs, handheld mode,
    and single Joy-Cons held sideways. Buttons are positional like on PC, so the
    bottom button (B) selects and jumps, as the in-game hints say. Rumble works.
  - Touch screen in handheld mode (the game's touch controls show up).
  - Sound through the audio renderer service.
  - Saves and the log go to the SD card (`sdmc:/switch/Godot/app_userdata/Kaiju Dawn/`
    and `sdmc:/switch/kaiju-dawn/log.txt`).
- `platform/compat/` and `platform/posix_stubs.c`: stand-ins for POSIX headers and
  calls that Horizon lacks (dynamic libraries, processes, syslog).
- Jolt physics and CSG are left out: Jolt has no Horizon support and the game uses neither.
- `patches/`: small changes to the engine source.
- `build.sh`: builds the engine, exports the game pack and makes the `.nro`.
- `docker-build.sh`: runs `build.sh` in devkitPro's Docker image (only Docker needed).
- `make_nsp.sh`: turns the build output into an `.nsp` with your own console keys.
- `nsp/kaiju-dawn.json`: process settings (NPDM) for the `.nsp`, title ID `01004B414A550000`.
- `icon.jpg`: the 256x256 icon shown in hbmenu and on the HOME menu.

## Build (Linux)

```sh
switch/docker-build.sh
```

The first run downloads the Godot source and compiles the engine, which takes
a long time; later runs reuse `~/.cache/kaiju-dawn-switch`. The result is
`export/switch/kaiju-dawn.nro`. The "Switch build" GitHub Actions workflow
does the same and uploads the files as an artifact.

## Play from hbmenu (.nro)

1. Copy `kaiju-dawn.nro` to `sdmc:/switch/` on the SD card.
2. Hold **R** while starting any installed game, so hbmenu opens with full RAM
   ("title takeover"). Starting it from the Album only gives about 440 MB,
   which is not enough; the game shows a message and exits in that case.
3. Pick Kaiju Dawn.

## Install as a title (.nsp)

`make_nsp.sh` needs [hacBrewPack](https://github.com/The-4n/hacBrewPack) and
`prod.keys` dumped from your own console with Lockpick_RCM:

```sh
switch/make_nsp.sh ~/switch/prod.keys
```

Install `export/switch/kaiju-dawn.nsp` with an installer such as DBI or
Tinfoil. The game then has its own icon on the HOME menu and always gets full RAM.

## Debugging

Without nxlink, stdout and stderr go to `sdmc:/switch/kaiju-dawn/log.txt`.
To see the log live, start the `.nro` with `nxlink -s kaiju-dawn.nro`.
