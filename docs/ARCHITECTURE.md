# Architecture

## Pipeline

```
SA-MP Runner.app (SwiftUI, arm64)        samp-runner (CLI)
              \                          /
               RunnerCore (Foundation-only Swift library)
                          │ spawns, with a tuned environment
                          ▼
   Wine 11 WoW64 (x86_64, under Rosetta 2 on Apple Silicon)
     samp.exe ──injects samp.dll──► gta_sa.exe (32-bit, Direct3D 9)
                          │
                       wined3d ── renderer=vulkan ──► winevulkan ► MoltenVK ► Metal
                               └─ renderer=gl ─────► opengl32 ► macOS OpenGL (on Metal)
```

The launcher never patches the game. It prepares the environment, then starts `samp.exe` (or `gta_sa.exe`) under Wine.

## RunnerCore modules

| File | Responsibility |
|---|---|
| `AppPaths` | Every on-disk location, derived from one root (`SAMP_RUNNER_HOME` overrides it) |
| `Settings` | User settings (renderer, FPS cap, nickname, HUD, Retina…), tolerant JSON decoding |
| `WineRuntime` | Catalog of pinned Wine builds (URL + SHA-256 + size), plus resolution to concrete binaries, including a custom Wine path |
| `RuntimeInstaller` | URLSession download with progress, SHA-256 verify (CryptoKit), `tar -xJf` into a staging dir, then an atomic move |
| `WinePrefix` | `wineboot --init`, keeping user folders inside the prefix, a single `reg import` (skipped when unchanged), `wineserver -w/-k` |
| `LaunchEnvironment` | Pure functions producing the exact env vars for maintenance and for the game |
| `RegistryFile` | Builds UTF-16 `.reg` files (Mac driver options, SA-MP `gta_sa_exe`/`PlayerName`) |
| `SAMPConfigFile` | Merges launcher keys (`fpslimit`, `multicore`) into `sa-mp.cfg` and keeps everything else |
| `GameFolder` | Recognises the 1.0 US exe, SA-MP files, DXVK leftovers vs mod proxies. Imports by APFS clone. Handles 1.x migration |
| `SAMPQuery` | SA-MP/open.mp UDP query protocol (info + ping), with Windows-1252 fallback for names |
| `ServerDirectory` | open.mp public list (`/servers/full`), favorites store |
| `Benchmark` | Parses wined3d `+frametime` traces into average FPS, 1% low and worst frame |
| `Runner` | Facade used by both front ends: setup, import, installers, launch/stop, session tracking, prefix reset, logs |
| `Doctor` | Diagnostics: Rosetta, runtime, prefix, game, DXVK leftovers, Low Power Mode, thermals, disk |

## Launch sequence

1. Resolve the Wine runtime and check that the prefix exists.
2. Keep `Documents`/`Desktop`/… as real folders in the prefix.
3. Import the registry file if its content changed (nickname, game path, Mac driver options).
4. Write `sa-mp.cfg` (`fpslimit`, `multicore`).
5. Spawn `wine "C:\Games\GTA San Andreas\samp.exe" [host:port]` with:
   - `WINE_D3D_CONFIG=renderer=…;csmt=0x1;VideoMemorySize=…`
   - `WINEDEBUG=-all` (or `-all,+frametime` in benchmark mode)
   - `WINEDLLOVERRIDES=mscoree,mshtml=;winemenubuilder.exe=d;d3d9=b`
   - user-interactive QoS, output to `logs/game-*.log`
6. When the first process exits, wait for `wineserver -w` (samp.exe hands off to gta_sa.exe), then parse the benchmark log if enabled.

## Data layout

```
~/Library/Application Support/SA-MP Runner/
  settings.json  favorites.json
  runtimes/wine-devel-11.18/Wine Devel.app/…
  prefix/                                   WoW64 prefix
    drive_c/Games/GTA San Andreas/          the game
    drive_c/users/<you>/Documents/GTA San Andreas User Files/   gta_sa.set, SAMP/sa-mp.cfg, USERDATA.DAT
  logs/                                     last 15 sessions
  wine/                                     1.x prefix (import only; deletable)
```

## Testing

- `RunnerCoreTests` run on macOS and Linux (`./scripts/test.sh`, CI runs both).
- `RunnerIntegrationTests` replaces `wine`/`wineserver` with shell scripts that record their arguments and environment. Setup, import, registry, `sa-mp.cfg`, launch, session end, benchmark parsing and prefix reset all run for real against them.
- `SAMPQueryTests` includes a real UDP round trip against a local fake server.
- The SwiftUI app is compiled by the macOS CI job. Its behaviour needs a Mac to test.
