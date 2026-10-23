# Sci-fi Windows desktop skin

A living, clickable sci-fi desktop for Windows, built on [Rainmeter](https://www.rainmeter.net/).
It started as a recreation of the old *Alien* (1979) website: a terminal readout, glowing
hotspot boxes over the scene and a poster-style title block. It grew into two themes,
**ARRAKIS** (Dune) and **NOSTROMO** (Alien).

The whole desktop uses about 10 MB of RAM and well under 0.1% CPU while idle.

> **Artwork is not included.** The wallpapers in the original setup are other people's art,
> so this repository ships the code, the generated UI art and the sounds only. Bring your own
> image and run the generator (see [Your artwork](#your-artwork)).

## What it does

| | |
|---|---|
| **Terminal** | Boots with a typewriter effect and lists your apps as numbered records, plus the clock, live weather, focus timer and status messages. Click a row to launch the app. |
| **Hotspot boxes** | Glowing boxes placed over the art. Hover for a cyan "scan" and the app name; click to launch. Running apps get an `[ACTIVE]` tag. |
| **Hidden records** | Three invisible hotspots. Find them all to unlock *Kwisatz Haderach mode* (blue palette, glowing eyes). |
| **Mentat** | Click **PROMPT** for an inline command line: app or folder names, `g` / `yt` / `w <search>`, maths (`12*48`), `focus 25`, `theme`, `cinema`, `guard off`. Type `?` for help. |
| **Day and night** | The wallpaper follows the clock through dawn, day, dusk and night (with stars). Strong wind at your weather location switches on a sandstorm version. |
| **Live weather** | From [Open-Meteo](https://open-meteo.com/) (no account needed); set with `install.ps1 -City "Your City"`. |
| **Two-moons clock** | Two moons orbit the planet as hour and minute hands. Click one to start a focus session, which draws a glowing arc around the planet. |
| **Cinema mode** | Click the title to fade everything except the title, date and moons. |
| **Sandworm** | A sand ripple crosses the dunes while something is downloading, faster as the download speeds up. |
| **Billing block** | Live CPU, memory, disk, network, battery and uptime, styled like a film poster's credits. |
| **Footer** | Settings, Task Manager, the Recycle Bin with its size (right-click to empty), and a theme switch. |
| **Intro** | A letterboxed title card at sign-in and on theme change. |
| **Sounds** | Soft hover, launch, discovery and focus-complete sounds; set `Sounds=0` to mute. |

## Requirements

- Windows 10 or 11, built for a **1920×1200** screen (other sizes need new positions in
  `install.ps1` and `build/make_assets.py`)
- [Rainmeter](https://www.rainmeter.net/) 4.5+: `winget install -e --id Rainmeter.Rainmeter`
- Python 3 with Pillow and NumPy, to generate the wallpapers: `pip install pillow numpy`

## Your artwork

The layout (planet, moon orbits, hotspot boxes, worm path) is tuned to one specific Dune
painting: a cloaked figure in front of a large teal planet. With a different image, adjust the
geometry at the top of `build/make_assets.py` and the box positions in `install.ps1`.

```powershell
# Dune image required, Alien image optional (enables the NOSTROMO theme)
python build\make_assets.py path\to\dune.jpg Arrakis\@Resources path\to\alien.jpg
```

This writes the 8 ARRAKIS wallpapers (dawn, day, dusk, night, each clear and sandstorm), the
NOSTROMO day and red-emergency night wallpapers, the scan thumbnails, and all UI images and sounds.

## Install

Double-click **`Install Arrakis.cmd`**, or run:

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1 -Autostart -Guard -City "Your City"
```

| Option | Effect |
|---|---|
| `-Autostart` | Starts Rainmeter with Windows |
| `-Guard` | Adds a scheduled task that restarts Rainmeter if it closes or freezes (pause with Mentat `guard off`) |
| `-City` | Sets up live weather (only the city name is sent to Open-Meteo) |
| `-Reset` | Overwrites your settings and saved state |

Re-running the installer keeps your edited settings and discoveries. It also writes
`install-log.txt` next to itself. Run it from a normal PowerShell window or by double-clicking:
it writes to your real user profile.

Right-click any element and choose **Edit apps and labels** to change the apps, folders and links.

## Uninstall

```powershell
powershell -ExecutionPolicy Bypass -File uninstall.ps1          # unload, restore your wallpaper, remove the guard
powershell -ExecutionPolicy Bypass -File uninstall.ps1 -Remove  # also delete the skin, layouts, DPI override and autostart
```

## How it is put together

- `Arrakis/` is the Rainmeter skin suite: one config per element, with shared settings in
  `@Resources/Variables.inc`, saved state in `State.inc` and per-theme text and colours in
  `Themes/`.
- Lua scripts in `@Resources/Scripts/` drive the terminal, sky, stats, worm and title logic.
  Skins redraw only when something changes.
- Four tiny helpers are compiled from readable C# by the installer, so that slow or heavy work
  never runs inside Rainmeter:
  - `SetWallpaper.exe` sets the wallpaper.
  - `Mentat.exe` is the input box, which keeps .NET out of Rainmeter.
  - `EmptyBin.exe` empties the Recycle Bin, so a huge bin can't freeze the desktop.
  - `Guard.exe` is the restart guard.
- `build/make_assets.py` generates every image and sound.

*Dune* and *Alien* are trademarks of their respective owners. This is an unofficial fan project.
