#!/bin/bash
# Builds duckstation.nro for the Nintendo Switch.
# Requires devkitPro with switch-dev and the switch portlibs (zstd, webp, zlib, mesa,
# png, jpeg, freetype, harfbuzz, curl, libdrm_nouveau, mesa), plus CMake and Ninja on PATH.
set -e

SRC_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-/tmp/opencode/build-switch}"
export DEVKITPRO="${DEVKITPRO:-/opt/devkitpro}"
export DEVKITA64="${DEVKITA64:-$DEVKITPRO/devkitA64}"

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

"$DEVKITPRO/portlibs/switch/bin/aarch64-none-elf-cmake" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_NOGUI_FRONTEND=ON \
  -DBUILD_QT_FRONTEND=OFF \
  -DENABLE_VULKAN=OFF \
  -DENABLE_CUBEB=OFF \
  -DENABLE_DEKO3D=OFF \
  -DCMAKE_DISABLE_PRECOMPILE_HEADERS=ON \
  "$SRC_DIR"

ninja duckstation-nogui_nro

echo "Built: $BUILD_DIR/duckstation.nro"
