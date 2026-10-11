# Troubleshooting

Start with **Diagnostics** in the app or `samp-runner doctor`. It checks Rosetta, the Wine runtime, the prefix, your game files, leftover DXVK DLLs, Low Power Mode, thermal throttling and disk space.

Logs are in `~/Library/Application Support/SA-MP Runner/logs/` (**Settings › Show Logs**). Wine logging is off by default for speed. To capture errors, run once with `samp-runner play --verbose` (or `connect … --verbose`).

## Setup

**Wine download fails or "checksum mismatch".** The launcher only accepts the exact pinned build. Upstream occasionally deletes old releases. Pick the other runtime in Settings › Wine (`samp-runner config runtime wine-stable-11.0_1`), or set **Custom wine binary** to a Wine you already have.

**"Bad CPU type in executable" / nothing happens on Apple Silicon.** Rosetta 2 is missing:
```bash
softwareupdate --install-rosetta --agree-to-license
```

**The app "can't be opened" (downloaded from GitHub Actions).** It's ad-hoc signed, not notarized. Right-click › Open once, or:
```bash
xattr -dr com.apple.quarantine "/Applications/SA-MP Runner.app"
```

**I used SA-MP Runner 1.x.** Setup shows **Import from previous SA-MP Runner** (CLI: `samp-runner import-legacy`). It moves the game out of the old `wine/` prefix and copies `~/Documents/GTA San Andreas User Files`, so your settings and SA-MP favorites come along. Add `--delete-old` to free the old prefix's disk space.

## Launching

**SA-MP says it can't find gta_sa.exe.** The launcher writes `HKCU\Software\SAMP\gta_sa_exe` before every launch. If it still happens, check that `C:\Games\GTA San Andreas\gta_sa.exe` exists (`samp-runner paths`).

**"Unrecognised gta_sa.exe".** SA-MP 0.3.7 needs the **1.0 US** executable (14,383,616 bytes). Other versions, including Steam/Rockstar Launcher builds, need downgrading first.

**Black screen, missing textures or flicker.** Switch the renderer to **OpenGL** (Settings, or `samp-runner config renderer opengl`). If OpenGL works and Vulkan doesn't, please open an issue with a `--verbose` log.

**Graphics broke after installing a mod, or "Leftover DXVK DLLs".** 1.x copied DXVK's `d3d9.dll`/`dxgi.dll` into the game folder. DXVK's D3D9 doesn't work on MoltenVK. Click **Disable Them** in Setup (`samp-runner fix-dxvk`). The files are renamed to `*.dxvk-disabled`, not deleted. For ReShade/ENB-style `d3d9.dll` mods, turn on **Load d3d9.dll mods** in Settings.

**Game stuck at 25–30 FPS.** The in-game **Frame Limiter** is on. Turn it off in Options › Display Setup, and SA-MP's cap (launcher setting) takes over.

**Stutter every few seconds.** Usually swap on 8 GB Macs. Close browsers and Electron apps, then check Memory Pressure in Activity Monitor. See [PERFORMANCE.md](PERFORMANCE.md).

**Walking (Left Alt) doesn't work.** Keep **Option key works as Alt** on (default).

**Game window floats over other apps / won't release the mouse.** Press Cmd-Tab to leave the game. Use fullscreen in the game's display settings rather than windowed mode.

## Servers

**SA-MP's own browser shows an empty Internet tab.** The old SA-MP master list is gone. Use the launcher's **Servers** tab, which uses the open.mp list, or add servers to Favorites.

**A server shows "–" for ping.** It didn't answer the UDP query within 1.5 s. It may be offline or block queries. You can still try to connect.

## Starting over

**Recreate Wine Prefix…** in Settings (`samp-runner reset-prefix --yes`) rebuilds the Windows environment. It keeps the game folder and `GTA San Andreas User Files` (settings, SA-MP favorites, chat logs).

To remove everything:
```bash
rm -rf ~/Library/Application\ Support/SA-MP\ Runner
```
This deletes the game copy inside the prefix too. Your original GTA folder isn't touched.
