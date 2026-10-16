#!/usr/bin/env bash
# Builds Kaiju Dawn for a Nintendo Switch running custom firmware (homebrew).
#
# Output in export/switch/:
#   kaiju-dawn.nro   copy to sdmc:/switch/ and start from hbmenu (title takeover)
#   nsp-input/       ready for switch/make_nsp.sh, which builds an installable .nsp
#
# Needs devkitPro (devkitA64, libnx, switch-mesa), scons, git, curl and unzip.
# Without devkitPro installed, run switch/docker-build.sh instead.
set -euo pipefail

GODOT_VERSION=4.4.1
GAME_VERSION=${GAME_VERSION:-0.1.0}
TITLE_ID=01004B414A550000

ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT=$ROOT/export/switch
# Kept outside the project so the Godot editor does not scan the engine source.
WORK=${WORK:-$HOME/.cache/kaiju-dawn-switch}
GODOT_SRC=${GODOT_SRC:-$WORK/godot}
GODOT_EDITOR=${GODOT_EDITOR:-$WORK/Godot_v${GODOT_VERSION}-stable_linux.x86_64}
JOBS=${JOBS:-$(nproc)}

: "${DEVKITPRO:?DEVKITPRO is not set (install devkitPro or use switch/docker-build.sh)}"
export PATH=$DEVKITPRO/tools/bin:$DEVKITPRO/devkitA64/bin:$PATH
mkdir -p "$WORK" "$OUT"
touch "$ROOT/export/.gdignore"

echo "== Godot $GODOT_VERSION source"
if [ ! -d "$GODOT_SRC/.git" ]; then
	git clone --depth 1 -b "$GODOT_VERSION-stable" https://github.com/godotengine/godot.git "$GODOT_SRC"
fi
rm -rf "$GODOT_SRC/platform/switch"
cp -r "$ROOT/switch/platform" "$GODOT_SRC/platform/switch"
for p in "$ROOT"/switch/patches/*.patch; do
	if git -C "$GODOT_SRC" apply --check "$p" 2>/dev/null; then
		git -C "$GODOT_SRC" apply "$p"
	elif ! git -C "$GODOT_SRC" apply --reverse --check "$p" 2>/dev/null; then
		echo "Patch does not apply: $p" >&2
		exit 1
	fi
done

echo "== Engine for Switch"
(cd "$GODOT_SRC" && scons platform=switch target=template_release -j"$JOBS")
ELF=$GODOT_SRC/bin/godot.switch.template_release.arm64

echo "== Game pack"
if [ ! -x "$GODOT_EDITOR" ]; then
	curl -sSLo "$WORK/editor.zip" "https://github.com/godotengine/godot/releases/download/$GODOT_VERSION-stable/Godot_v$GODOT_VERSION-stable_linux.x86_64.zip"
	unzip -qo "$WORK/editor.zip" -d "$WORK"
	rm "$WORK/editor.zip"
fi
(cd "$ROOT" && "$GODOT_EDITOR" --headless --import >/dev/null 2>&1 || true)
(cd "$ROOT" && "$GODOT_EDITOR" --headless --export-pack "Switch" "$OUT/game.pck")
test -s "$OUT/game.pck"

echo "== kaiju-dawn.nro"
rm -rf "$WORK/romfs" && mkdir -p "$WORK/romfs"
cp "$OUT/game.pck" "$WORK/romfs/game.pck"
nacptool --create "Kaiju Dawn" "returnnull" "$GAME_VERSION" "$WORK/kaiju-dawn.nacp"
elf2nro "$ELF" "$OUT/kaiju-dawn.nro" --icon="$ROOT/switch/icon.jpg" --nacp="$WORK/kaiju-dawn.nacp" --romfsdir="$WORK/romfs"

echo "== nsp-input"
NSP=$OUT/nsp-input
rm -rf "$NSP" && mkdir -p "$NSP/exefs" "$NSP/romfs" "$NSP/control"
elf2nso "$ELF" "$NSP/exefs/main"
npdmtool "$ROOT/switch/nsp/kaiju-dawn.json" "$NSP/exefs/main.npdm"
cp "$OUT/game.pck" "$NSP/romfs/game.pck"
cp "$WORK/kaiju-dawn.nacp" "$NSP/control/control.nacp"
cp "$ROOT/switch/icon.jpg" "$NSP/control/icon_AmericanEnglish.dat"
echo "$TITLE_ID" > "$NSP/titleid.txt"

ls -la "$OUT"
echo "Done: $OUT/kaiju-dawn.nro"
