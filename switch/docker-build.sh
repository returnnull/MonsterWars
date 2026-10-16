#!/usr/bin/env bash
# Runs switch/build.sh inside devkitPro's official devkitA64 Docker image, so
# only Docker is needed on the host. The engine checkout is cached in
# ~/.cache/kaiju-dawn-switch between runs.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
CACHE=${CACHE:-$HOME/.cache/kaiju-dawn-switch}
IMAGE=${IMAGE:-devkitpro/devkita64:latest}
mkdir -p "$CACHE"

docker run --rm \
	-v "$ROOT":/game -v "$CACHE":/cache \
	-e WORK=/cache -e HOME=/cache -e GAME_VERSION="${GAME_VERSION:-0.1.0}" \
	-u 0 "$IMAGE" bash -c '
		set -e
		if ! command -v scons >/dev/null; then
			apt-get update -qq && apt-get install -y -qq scons git curl unzip >/dev/null
		fi
		/game/switch/build.sh
		chown -R '"$(id -u):$(id -g)"' /game/export /cache
	'
