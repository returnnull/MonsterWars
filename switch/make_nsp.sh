#!/usr/bin/env bash
# Packs export/switch/nsp-input (made by build.sh) into an installable .nsp.
#
# Usage: switch/make_nsp.sh /path/to/prod.keys
#
# prod.keys must be dumped from your own console (Lockpick_RCM). They are
# never stored in this repository. Needs hacBrewPack:
# https://github.com/The-4n/hacBrewPack (build it with `make`, or set HACBREWPACK).
set -euo pipefail

KEYS=${1:?Usage: $0 /path/to/prod.keys}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
IN=$ROOT/export/switch/nsp-input
OUT=$ROOT/export/switch
HACBREWPACK=${HACBREWPACK:-hacbrewpack}

test -f "$IN/exefs/main" || { echo "Run switch/build.sh first." >&2; exit 1; }
TITLE_ID=$(cat "$IN/titleid.txt")

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cd "$TMP"
"$HACBREWPACK" -k "$KEYS" --titleid "$TITLE_ID" \
	--exefsdir "$IN/exefs" --romfsdir "$IN/romfs" --controldir "$IN/control" \
	--nspdir "$TMP/nsp"
cp "$TMP"/nsp/*.nsp "$OUT/kaiju-dawn.nsp"
echo "Done: $OUT/kaiju-dawn.nsp"
