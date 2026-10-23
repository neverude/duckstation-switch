# DuckStation for Nintendo Switch

This is a Nintendo Switch port of [DuckStation](https://github.com/stenzek/duckstation), a PlayStation 1 (PSX) emulator. It runs as a homebrew application (`duckstation.nro`) on a modified Switch.

If you have never run homebrew before, start with the **[NH Switch Guide](https://switch.hacks.guide)**. It walks you through installing Atmosphère, hekate and the Homebrew Menu (hbmenu). Nothing in this README replaces that guide, and DuckStation cannot run on a stock Switch.

Upstream DuckStation (PC, Android, macOS) is documented in [README.md](https://github.com/stenzek/duckstation/blob/master/README.md). This file covers only the Switch port.

## What you need

- A Switch running custom firmware (Atmosphère) with the Homebrew Menu, set up as described in the [NH Switch Guide](https://switch.hacks.guide)
- A microSD card with a copy of `duckstation.nro` (see [Building](#building) or ask for a prebuilt file)
- A PlayStation 1 BIOS dump from your own console. It is not included and cannot be shared with this project.
- PS1 game images you own. Supported formats are the same as upstream: `.bin/.cue`, `.img`, `.chd`, `.ecm`, `.mds/.mdf` and `.pbp`.

## Installation

1. Create the folder `sdmc:/switch/duckstation/` on the microSD card.
2. Copy `duckstation.nro` into that folder.
3. Create a `bios` folder inside it (`sdmc:/switch/duckstation/bios/`) and copy your PS1 BIOS file there.
4. Copy your game images anywhere on the card, for example `sdmc:/roms/psx/`, and add that folder as a game directory in DuckStation's settings.

DuckStation keeps its settings, memory cards, save states and BIOS next to `duckstation.nro`. If you put a `settings.ini` or `portable.txt` next to the `.nro`, it uses that folder for data in the same way.

## Starting DuckStation

DuckStation must run in **application mode**. It refuses to start when hbmenu is opened through the Album applet.

1. Return to the Home menu.
2. Start an installed game (not the Album).
3. Hold **R** while pressing **A** to launch it, until hbmenu appears.
4. Start DuckStation from hbmenu.

If you see the message "DuckStation needs to run in application mode", repeat these steps. The NH Switch Guide explains "title takeover", which gives homebrew the resources it needs. Set it up before you try this.

## Controls

These are the defaults on the Switch controller. You can change them in the settings.

| Switch input | PS1 action |
| --- | --- |
| A / B / X / Y | Circle / Cross / Triangle / Square |
| Plus / Minus | Start / Select |
| D-Pad, left stick | D-Pad, analog stick |
| L / R, ZL / ZR | L1 / R1, L2 / R2 |
| Right stick press (R3) | Pause menu |
| Left stick press (L3) | Toggle fast forward |

Shortcuts (hold the first button, then press the second):

| Shortcut | Action |
| --- | --- |
| ZL + ZR | Open the pause menu |
| ZR + B | Quick save |
| ZR + Y | Quick load |
| ZR + X | Cycle the aspect ratio |

Menus are navigated with the left stick. The first time you start the emulator, hints are shown for these controls.

## Display and performance defaults

- **Aspect ratio:** stretched to fill the screen, with the borders cropped. Use ZR + X to change it.
- **Clock speeds:** the port raises the clocks when it starts (CPU 1785 MHz, GPU 768 MHz, memory 1600 MHz). You can turn this off in the settings under `Switch`.
- **CD images:** the disc is read into RAM once when loading. This avoids slow SD card reads during play. It needs enough free memory for the game image.
- **Renderer:** OpenGL ES through switch-mesa. Vulkan and the deko3d backend are not enabled in the default build.

Changes you make in the menus are kept. Defaults are only applied once per version of the port.

## Logs and troubleshooting

Log files are written to the microSD card so you can read them after a crash:

- `sdmc:/switch/duckstation/duckstation.log`: startup and runtime log
- `sdmc:/switch/duckstation/crash.txt`: crash report, written when DuckStation crashes

To get more detailed logs, create an empty file at `sdmc:/switch/duckstation/debug.txt`. Delete it when you are done, since verbose logging writes a lot to the SD card.

When you report a problem, include the log file and the crash report if there is one. Also include your Atmosphère version, firmware version, the game name, and whether it happens on the same game every time.

Known issues:

- The port is marked **pre-release**. Expect rough edges and games that do not run correctly.
- LibCrypt games need the matching `.sbi` file next to the disc image. See the LibCrypt section of the upstream README.

## Building

Building needs devkitPro with `devkitA64`, `libnx` and the Switch portlibs (zstd, webp, zlib, mesa, png, jpeg, freetype, harfbuzz, curl, libdrm_nouveau), plus CMake and Ninja on your `PATH`. The build script is the supported way to build:

```bash
./scripts/build-switch.sh
```

The script writes its build to `/tmp/opencode/build-switch` by default. Set `BUILD_DIR` to change this, and `DEVKITPRO` if devkitPro is not in `/opt/devkitpro`. The output is `duckstation.nro` in the build folder.

The build uses these options: `BUILD_SWITCH_FRONTEND=ON`, `BUILD_QT_FRONTEND=OFF`, `ENABLE_VULKAN=OFF`, `ENABLE_CUBEB=OFF`, `ENABLE_DEKO3D=OFF`.

## Where the code is

- `src/duckstation-switch/`: the Switch frontend (`frontend_host.cpp`, `switch_frontend_platform.cpp`)
- `src/util/switch_*`: Switch input, controller, and audio backends
- `src/util/deko3d_*`: the deko3d renderer. It is included in the source but not enabled in the default build.
- `scripts/build-switch.sh`: the build script
- `extras/icons/icon-switch.jpg`: the icon shown in hbmenu

## Credits

- DuckStation is by Connor McLaughlin (stenzek) and its contributors. See [CONTRIBUTORS.md](CONTRIBUTORS.md).
- The Switch port is by RSDuck and this fork's contributors.
- The NH Switch Guide is by the Nintendo Homebrew community.

## License

DuckStation is licensed under the GNU General Public License v3. See [LICENSE](LICENSE).
