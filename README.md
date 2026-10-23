# DuckStation for Nintendo Switch

DuckStation is a PlayStation 1 (PS1) emulator. This is a version that runs on the Nintendo Switch. It is a homebrew app: a program that is not part of the official Switch software.

This guide is for people who have never modded a console before. Read each step fully before you do it.

> **Important:** Only do this on a Switch you own. Running homebrew needs custom firmware, which is a modification of the console. Follow the [NH Switch Guide](https://switch.hacks.guide) for that part. This README does not replace it.

---

## Before you start: what you need

- A Nintendo Switch that runs **custom firmware (Atmosphère)** with the **Homebrew Menu (hbmenu)**. If you do not have this yet, follow the [NH Switch Guide](https://switch.hacks.guide) first. It takes about an hour.
- A **microSD card** that is in the Switch, plus a way to plug it into a computer (a card reader or a built-in slot).
- A computer running Windows, macOS or Linux.
- A **PS1 BIOS file** from a PlayStation you own. It is not included here, and this project cannot give it to you.
- **PS1 game files** that you own (for example `.bin` + `.cue`, or `.chd`).

---

## Step 1: Get `duckstation.nro`

`duckstation.nro` is the file that runs on the Switch. There are two ways to get it.

### Option A: Download it (recommended)

1. Open the **[Releases page](https://github.com/neverude/duckstation-switch/releases/latest)**.
2. Under **Assets**, click **duckstation.nro** to download it.

### Option B: Build it yourself (advanced)

Only do this if you want to change the code or the release file is not available. It needs a developer tool called devkitPro. Install it first using the [devkitPro Getting Started guide](https://devkitpro.org/wiki/Getting_Started), including the **switch-dev** package.

Then open a terminal in the folder of this repository and run:

```bash
./scripts/build-switch.sh
```

The finished file is saved as `dist/duckstation.nro`. The script can also copy it to your SD card (see Step 2).

---

## Step 2: Copy it to the SD card

1. Turn off the Switch and take out the microSD card.
2. Plug the card into your computer and open it.
3. Create these folders on the card, if they do not already exist: `switch`, then `duckstation` inside it.
4. Copy `duckstation.nro` into the `duckstation` folder.

The card must end up with this path:

```
switch/duckstation/duckstation.nro
```

The name must be exactly `duckstation.nro`.

> **Tip:** If you built it with the script, you can skip the manual copy. Run `./scripts/build-switch.sh /path/to/your/card` and it copies the file to the right place.

Then **eject the card safely** (use your computer's eject option) before you put it back into the Switch.

---

## Step 3: Start DuckStation on the Switch

DuckStation must start in **application mode**. Otherwise it stops with an error message.

1. Put the microSD card back into the Switch and turn it on.
2. Go to the **Home menu**.
3. Select any installed **game** (not the Album app).
4. Press and hold **R**, and press **A** to start the game. Keep holding R until the **Homebrew Menu** appears.
5. In the Homebrew Menu, select **duckstation** and start it.

If you see the message *"DuckStation needs to run in application mode"*, go back to the Home menu and repeat these steps.

---

## Step 4: Add the BIOS and your games

The BIOS is the small program that every PS1 needs to start.

1. On the SD card, open `switch/duckstation`.
2. Create a folder named `bios`.
3. Copy your PS1 BIOS file into `switch/duckstation/bios/`.
4. Copy your game files to a folder on the card, for example `roms/psx/`.
5. In DuckStation, open the settings and add that folder as a game folder. Your games will then show up in the list.

---

## Step 5: Controls

These are the default controls. You can change them in the settings.

| Switch button | PS1 button |
| --- | --- |
| A / B / X / Y | Circle / Cross / Triangle / Square |
| Plus / Minus | Start / Select |
| D-Pad, left stick | D-Pad, analog stick |
| L / R, ZL / ZR | L1 / R1, L2 / R2 |

Useful shortcuts. Hold the first button, then press the second:

| Shortcut | What it does |
| --- | --- |
| ZL + ZR | Open the pause menu |
| ZR + B | Quick save |
| ZR + Y | Quick load |
| ZR + X | Change the screen shape |

Press the **right stick** to open the pause menu. Press the **left stick** to turn fast-forward on or off.

The first time you start DuckStation, it shows hints for these controls.

---

## Something does not work?

- **The Homebrew Menu does not appear:** repeat Step 3 exactly. Hold R while pressing A on a game, not on the Album app.
- **"Application mode" error:** same as above. Start from a game, not from the Album.
- **DuckStation closes or freezes:** check the file `switch/duckstation/crash.txt` on the SD card. Also look at `switch/duckstation/duckstation.log`.
- **A game does not start:** check that the BIOS is in `switch/duckstation/bios/`.
- **Still stuck:** open an issue at the [issue page](https://github.com/neverude/duckstation-switch/issues) and attach `duckstation.log` and `crash.txt` if they exist. Tell us your Atmosphère version, your Switch firmware version, and the game name.

The app is in **pre-release**. Some games will not work properly yet.

---

## For developers

- Build: `./scripts/build-switch.sh` (see Option B above). Set `BUILD_DIR` to change where the build goes (default: `~/.cache/duckstation-switch-build`).
- Output: `dist/duckstation.nro`. Using `--build-only` builds without touching any SD card.
- Source layout:
  - `src/duckstation-switch/`: the Switch frontend (`frontend_host.cpp`, `switch_frontend_platform.cpp`)
  - `src/util/switch_*`: Switch input, controller and audio backends
  - `src/util/deko3d_*`: deko3d renderer (included, not enabled in the default build)
  - `scripts/build-switch.sh`: build and copy script
  - `extras/icons/icon-switch.jpg`: icon shown in the Homebrew Menu
- Build options passed to CMake: `BUILD_SWITCH_FRONTEND=ON`, `BUILD_QT_FRONTEND=OFF`, `ENABLE_VULKAN=OFF`, `ENABLE_CUBEB=OFF`, `ENABLE_DEKO3D=OFF`.
- Default settings for the Switch are applied once per version (`SWITCH_DEFAULTS_VERSION` in `src/duckstation-switch/frontend_host.cpp`).

For the emulator itself (PC, Android, macOS), see the upstream [DuckStation README](https://github.com/stenzek/duckstation/blob/master/README.md).

---

## Credits and license

- DuckStation is by Connor McLaughlin (stenzek) and its contributors. See [CONTRIBUTORS.md](CONTRIBUTORS.md).
- The Switch port is by RSDuck and the contributors of this fork.
- The NH Switch Guide is by the Nintendo Homebrew community.
- DuckStation is licensed under the GNU General Public License v3. See [LICENSE](LICENSE).
