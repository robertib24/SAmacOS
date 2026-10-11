# Mods

Mods live in the game folder (`samp-runner paths` › game, or **Settings › Show Game Folder**). Most SA-MP servers only allow client-side visual and fix mods. Check the server's rules first.

## Recommended

- **SilentPatch** (CookiePLMonster): fixes hundreds of original bugs, including frame-timing issues, and is widely used with SA-MP. Needs an ASI loader. The usual one for GTA SA is the *Ultimate ASI Loader* installed as `vorbisFile.dll`, with the original renamed to `vorbisHooked.dll`. Follow the instructions shipped with each mod.

## d3d9.dll mods (ReShade, ENB, graphics proxies)

By default the launcher forces Wine's own `d3d9`, so a `d3d9.dll` in the game folder is ignored. This stops stale DXVK copies from 1.x from breaking rendering. Turn on **Settings › Load d3d9.dll mods** (`samp-runner config d3d9-mods on`) to let a proxy load. Post-processing mods cost GPU and CPU time, so measure with Benchmark mode.

## SAMP Addon

SAMP Addon replaces some SA-MP files. Install order matters:

1. GTA San Andreas
2. SAMP Addon
3. **SA-MP again**: run the SA-MP installer once more (Setup › *Run Installer Again…*), or the game won't start.

Run each installer from the launcher (Setup, or `samp-runner install-samp <installer.exe>`) so it goes into the right prefix. Choose `C:\Games\GTA San Andreas` when asked.

## Don't

- Don't copy DXVK DLLs into the game folder. DXVK's D3D9 doesn't run on MoltenVK.
- Don't edit `gta_sa.set` by hand. It's a binary file. Change settings in the game's menu.
