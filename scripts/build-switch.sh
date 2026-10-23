#!/bin/bash
# Builds duckstation.nro for the Nintendo Switch and copies it to the microSD card.
#
# Usage:
#   ./scripts/build-switch.sh                    build, then copy to the SD card if exactly one is found
#   ./scripts/build-switch.sh /path/to/sdcard    build, then copy to that card (the mount point)
#   ./scripts/build-switch.sh --build-only       build only, do not touch any SD card
#
# Needs devkitPro (devkitA64, libnx, portlibs), CMake and Ninja.
set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$HOME/.cache/duckstation-switch-build}"
export DEVKITPRO="${DEVKITPRO:-/opt/devkitpro}"
export DEVKITA64="${DEVKITA64:-$DEVKITPRO/devkitA64}"
CMAKE="$DEVKITPRO/portlibs/switch/bin/aarch64-none-elf-cmake"
NRO_NAME="duckstation.nro"
SD_SUBDIR="switch/duckstation"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

# 1. Check tools
[ -x "$CMAKE" ] || die "devkitPro CMake not found at $CMAKE. Install devkitPro with the switch-dev and portlibs packages, or set DEVKITPRO."
[ -d "$DEVKITA64" ] || die "devkitA64 not found at $DEVKITA64."
command -v ninja >/dev/null 2>&1 || die "ninja is not installed (install the 'ninja' package)."

# 2. Work out where the card is, before the slow build starts
MODE="auto"
SD_CARD=""
case "${1:-}" in
  --build-only) MODE="none" ;;
  "") ;;
  *) SD_CARD="${1%/}"; MODE="explicit" ;;
esac

if [ "$MODE" = "auto" ]; then
  mapfile -t CANDIDATES < <(find "/run/media/$USER" "/media/$USER" -mindepth 1 -maxdepth 1 -type d 2>/dev/null || true)
  if [ "${#CANDIDATES[@]}" -eq 1 ]; then
    SD_CARD="${CANDIDATES[0]}"
  elif [ "${#CANDIDATES[@]}" -gt 1 ]; then
    echo "More than one drive is mounted, so the SD card is not picked automatically:"
    printf '  %s\n' "${CANDIDATES[@]}"
    echo "Run again with the right one, e.g.: ./scripts/build-switch.sh \"${CANDIDATES[0]}\""
    MODE="none"
  else
    echo "No mounted SD card found. The .nro will be built but not copied."
    MODE="none"
  fi
fi

if [ "$MODE" != "none" ]; then
  # Refuse to continue if the target is not a real, mounted, writable card folder
  [ -d "$SD_CARD" ] || die "'$SD_CARD' is not a folder. Plug in the microSD card and check the path."
  mountpoint -q "$SD_CARD" || die "'$SD_CARD' is not a mounted drive. Refusing to copy into a normal folder."
  [ -w "$SD_CARD" ] || die "'$SD_CARD' is not writable. Check that the card is mounted and not read-only."
  echo "SD card: $SD_CARD"
fi

# 3. Build
echo "Building into $BUILD_DIR ..."
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

"$CMAKE" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SWITCH_FRONTEND=ON \
  -DBUILD_QT_FRONTEND=OFF \
  -DENABLE_VULKAN=OFF \
  -DENABLE_CUBEB=OFF \
  -DENABLE_DEKO3D=OFF \
  -DCMAKE_DISABLE_PRECOMPILE_HEADERS=ON \
  "$SRC_DIR"

ninja duckstation-switch_nro

BUILT="$BUILD_DIR/$NRO_NAME"
[ -s "$BUILT" ] || die "Build finished but $BUILT was not created."

# Always keep a copy in dist/ inside the repository
DIST_DIR="$SRC_DIR/dist"
mkdir -p "$DIST_DIR"
cp "$BUILT" "$DIST_DIR/$NRO_NAME"
BUILT="$DIST_DIR/$NRO_NAME"
echo "Built: $BUILT"

if [ "$MODE" = "none" ]; then
  echo
  echo "Next step: copy it to  /<where-the-sd-card-is-mounted>/$SD_SUBDIR/$NRO_NAME"
  echo "Or run:    ./scripts/build-switch.sh /<where-the-sd-card-is-mounted>"
  exit 0
fi

# 4. Copy safely: write a temp file, verify it byte for byte, then rename into place
DEST_DIR="$SD_CARD/$SD_SUBDIR"
DEST="$DEST_DIR/$NRO_NAME"
TMP="$DEST_DIR/.$NRO_NAME.tmp"

mkdir -p "$DEST_DIR"
cp "$BUILT" "$TMP"
cmp -s "$BUILT" "$TMP" || { rm -f "$TMP"; die "Copy check failed. Nothing was replaced on the card."; }
mv -f "$TMP" "$DEST"
sync
cmp -s "$BUILT" "$DEST" || die "Final check failed for $DEST. Copy again."

echo
echo "Done. Copied to: $DEST"
echo "Your BIOS goes in:  $DEST_DIR/bios/"
echo "Then eject the card safely and follow the README, section 3, to start it."
