# SA-MP Runner for macOS

Play GTA San Andreas Multiplayer (SA-MP and open.mp servers) on a Mac. Built and tuned for Apple Silicon (tested target: MacBook Pro M2, 8 GB), and also works on Intel Macs.

```
gta_sa.exe + samp.dll  (32-bit, Direct3D 9)
        │
Wine 11 (WoW64) ── runs on Rosetta 2 on Apple Silicon
        │
wined3d ──► Vulkan ──► MoltenVK ──► Metal     (default: "Vulkan" renderer)
        └─► OpenGL ──► Apple GL-on-Metal       (fallback: "OpenGL" renderer)
```

## What's new in 2.0 and why it's faster

Version 2.0 is a rewrite. The 1.x launcher had stopped working and was slower than it needed to be:

| 1.x problem | 2.0 |
|---|---|
| Installed Wine through Homebrew. Homebrew **disabled all Wine casks on 2026‑09‑01**, so fresh installs fail. | Downloads the WineHQ 11 macOS build (Gcenx) directly, pinned to a SHA‑256, into the app's own folder. No Homebrew, nothing system-wide. |
| Rendered through wined3d's **OpenGL** path. In Wine's WoW64 mode, which current macOS Wine builds use, 32‑bit games' OpenGL buffer maps are **copied** on every map (see `dlls/opengl32/unix_wgl.c`). | Defaults to wined3d's **Vulkan** renderer via MoltenVK, which maps memory straight into the 32‑bit game. OpenGL stays one click away as a fallback. |
| "Performance presets" wrote INI text into `gta_sa.set` (a binary file) in the game folder, where the game never reads it. `sa-mp.cfg` was written to the wrong folder too. The presets did nothing. | Writes `sa-mp.cfg` where SA-MP actually reads it (`Documents/GTA San Andreas User Files/SAMP`). Leaves `gta_sa.set` alone and tells you which in-game options matter. |
| Set Linux-only or long-removed options (esync/fsync, `__GL_*`, `UseGLSL`, `DirectDrawRenderer`, a malformed `WINE_CPU_TOPOLOGY`, DXVK on Apple Silicon). | Only options Wine 11, MoltenVK and Metal actually read, all covered by unit tests. |
| ~20 separate `wine reg add` processes on setup. | One `reg import`, skipped entirely when nothing changed. |
| Wine linked "My Documents" to `~/Documents`, so macOS privacy prompts appeared and files ended up outside the app. | Documents/Desktop/etc. live inside the prefix. |
| The "performance monitor" showed the launcher's own CPU use. | Benchmark mode records every frame from Wine and reports **average FPS and 1% lows** after you play. The Metal HUD shows live FPS. |

There are no FPS claims here: nobody has measured this build on your Mac yet. Use **Benchmark mode** to compare the Vulkan and OpenGL renderers on your machine. See [docs/PERFORMANCE.md](docs/PERFORMANCE.md).

## Requirements

- macOS 13 Ventura or newer, on Apple Silicon (with Rosetta 2) or Intel
- Your own **GTA San Andreas** (PC, the **1.0 US** `gta_sa.exe` that SA-MP needs)
- The **SA-MP 0.3.7** (or 0.3.DL) client, either already in your game folder or as an installer `.exe`
- About 1.5 GB free for Wine and the prefix, plus the game

## Getting started

### 1. Build the app

```bash
xcode-select --install          # once, if you don't have Xcode
./scripts/build.sh
open "build/SA-MP Runner.app"   # or copy it to /Applications
```

Every push also produces a ready-made build. Open the latest run under **Actions › CI** and download the `SA-MP-Runner-macOS` artifact. It isn't notarized, so right-click › Open the first time.

### 2. Setup (in the app)

1. **Download & Install Wine** (~190 MB, checksum-verified). The Wine prefix is created right after.
2. **GTA San Andreas**: choose the folder that contains `gta_sa.exe`. If you used SA-MP Runner 1.x, click **Import from previous SA-MP Runner** instead. That moves the game out of the old prefix and keeps your settings and SA-MP favorites.
3. **SA-MP**: if `samp.exe` is missing, run the SA-MP installer and pick `C:\Games\GTA San Andreas`.
4. If leftover DXVK files from 1.x are found, click **Disable Them**.

### 3. Play

- **Play** opens SA-MP's own browser. **Servers** has a native browser with the open.mp public list, favorites and live ping.
- In the game, set **Options › Display Setup › Frame Limiter: Off**. The launcher's FPS cap (default 60) then applies through SA-MP.

### Command line

Everything the app does is available from Terminal. The tool is `build/samp-runner`, and it also sits inside the app bundle.

```bash
samp-runner setup                         # download Wine, create prefix
samp-runner import-legacy --delete-old    # or: samp-runner import-game ~/Games/GTA\ San\ Andreas
samp-runner connect 1.2.3.4:7777
samp-runner config renderer opengl        # vulkan | opengl
samp-runner config benchmark on           # then play; results print when the game closes
samp-runner servers roleplay              # search the open.mp list
samp-runner doctor                        # diagnose slowness / setup issues
samp-runner help
```

## Alternatives that were evaluated

| Option | Why it isn't the default |
|---|---|
| **Apple D3DMetal (GPTK)** | Direct3D 11/12 and 64-bit only. GTA SA is 32-bit Direct3D 9. |
| **DXMT** (Metal D3D11) | Upstream supports D3D10/11 only. D3D9 exists only in experimental forks. |
| **DXVK** | DXVK-macOS targets D3D10/11, and upstream DXVK 2.x needs Vulkan features MoltenVK doesn't have. The 1.x attempt to use it is why "WineD3D fallback" code existed. |
| **CrossOver** (paid) | Very good, and fine to use directly. You can also point **Settings › Wine › Custom wine binary** at another Wine engine to try it with this prefix. |
| **Whisky** | No longer maintained (2025). |
| **Parallels / UTM VM** | Windows on Arm plus x86 emulation needs 4+ GB of an 8 GB Mac on its own. |
| **Native port** | There is no complete GTA SA source port, and SA-MP needs the original 1.0 US executable anyway. |

## Project layout

```
MacLauncher/                 Swift package
  Sources/RunnerCore/        all logic, Foundation-only, unit-tested on macOS + Linux
  Sources/samp-runner/       command-line tool
  Sources/SAMPRunner/        SwiftUI app
  Tests/RunnerCoreTests/     unit + end-to-end tests (fake wine)
scripts/                     build.sh, run-dev.sh, test.sh
docs/                        ARCHITECTURE, PERFORMANCE, TROUBLESHOOTING, MODS
```

Data lives in `~/Library/Application Support/SA-MP Runner/`. Run `samp-runner paths` to see exact locations.

## Legal

This project ships no game files, no SA-MP files and no Wine binaries. You need your own copy of GTA San Andreas. Wine is downloaded from the WineHQ macOS builds at setup time. MIT licensed. See [LICENSE](LICENSE).

## Credits

Rockstar Games (GTA San Andreas) · SA-MP team · open.mp · the Wine project · Gcenx (WineHQ macOS builds) · MoltenVK
