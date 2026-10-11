# Performance guide (Apple Silicon, 8 GB)

## Where the time goes

GTA San Andreas is a 2004 game. An M2's GPU renders it with almost no effort, so **the bottleneck is the CPU**:

1. **Rosetta 2** translates Wine's x86 code to ARM. That's fast, but every instruction still goes through it.
2. **Wine** turns Windows calls into macOS calls.
3. **Direct3D 9 translation**: GTA SA issues thousands of small draw calls per frame. wined3d processes each one on a separate render thread (`csmt`, on by default) and hands it to Vulkan or OpenGL.
4. **GTA SA itself** is single-threaded and does more work as draw distance grows.

The settings that help most therefore reduce **CPU work per frame**: draw distance, visual effects, objects on screen. Dropping resolution to 640×480, as the 1.x launcher did, barely helps, because the GPU wasn't the problem. Retina mode is the exception. It quadruples the pixel count, so keep it off.

## Renderer: Vulkan vs OpenGL

Current macOS Wine builds use **WoW64**: a single 64-bit Wine runs 32-bit games like GTA SA. When a 32-bit game maps a GPU buffer:

- **OpenGL path**: macOS returns a 64-bit pointer the 32-bit game can't use. Unless it happens to land below 4 GB, Wine allocates a low-memory buffer and **copies** the data in and out ("Doing a copy of a mapped buffer (expect performance issues)" in `dlls/opengl32/unix_wgl.c`).
- **Vulkan path**: Wine maps the memory directly into the 32-bit address space (`VK_EXT_map_memory_placed` or `VK_EXT_external_memory_host` in `dlls/win32u/vulkan.c`). No copies.

That's why **Vulkan is the default**. wined3d's Vulkan renderer is younger than its OpenGL one, so if you see missing textures, flicker or a black screen, switch to **OpenGL** in Settings (or `samp-runner config renderer opengl`). Better still, measure both:

## Measuring (do this, it's quick)

1. Settings › **Benchmark mode** on (CLI: `samp-runner config benchmark on`).
2. Play 2–3 minutes in a repeatable spot, for example the same drive along the same street on the same server. Loading screens and the first 10 seconds are ignored.
3. Close the game. The Play screen shows **average FPS**, **1% low** (average of the slowest 1% of frames, which is what stutter feels like) and the worst frame time.
4. Switch renderer, repeat, compare.

Benchmark mode makes Wine log one line per frame, which costs a little CPU. Turn it off for normal play. For a live counter use **Show Metal performance HUD** instead.

## In-game settings (M2, 8 GB)

| Setting | Recommendation | Why |
|---|---|---|
| Frame Limiter | **Off** | On, the game caps at 25–30 FPS. Off, SA-MP's `fpslimit` (launcher setting, default 60) caps it. |
| Resolution | 1440×900 or 1280×800 | Matches the 13" MacBook's default "looks like" size. GPU cost is small either way. |
| Draw Distance | Medium, raise if FPS allows | The biggest CPU cost, especially on mapped servers. |
| Visual FX Quality | Low/Medium | Shadows and effects add draw calls. |
| Anti-aliasing | Off | Cheap on GPU, but no benefit at this resolution. |

Use SA-MP's in-game `/fpslimit` to try caps quickly. The launcher's value is written to `sa-mp.cfg` at every launch.

## macOS side

- **Low Power Mode off** while playing (`samp-runner doctor` warns about it). It caps CPU and GPU clocks.
- **Memory**: Wine, GTA SA and SA-MP need roughly 1–1.5 GB. On 8 GB, browsers and Electron apps (Discord, Slack, VS Code) push the system into swap, which shows up as long stutters. Check Activity Monitor › Memory › *Memory Pressure*. Yellow or red means close something.
- **Disk**: keep 10+ GB free so swap has room.
- **Thermals**: the 13-inch MacBook Pro (M2) has a fan and rarely throttles. If `doctor` reports throttling, check the vents.

## What the launcher sets and why

| Setting | Value | Purpose |
|---|---|---|
| `WINE_D3D_CONFIG` | `renderer=vulkan\|gl;csmt=0x1;VideoMemorySize=2048` | Renderer per launch, threaded command stream, VRAM reported to the game |
| `WINEDEBUG` | `-all` | Wine logging costs CPU, so it's off unless benchmarking (`+frametime`) or `--verbose` |
| `WINEDLLOVERRIDES` | `mscoree,mshtml=;winemenubuilder.exe=d;d3d9=b` | No Mono/Gecko installs, no Launchpad entries, always Wine's d3d9 (unless you allow d3d9.dll mods) |
| `MVK_CONFIG_RESUME_LOST_DEVICE` | `1` | Recover instead of crashing if Metal reports a lost device |
| `MTL_HUD_ENABLED` | `1` (optional) | Apple's Metal performance HUD |
| Mac Driver `RetinaMode` | `n` | Render at "looks like" resolution, not 4× pixels |
| Process QoS | user-interactive | Keeps Wine on the performance cores |
| `sa-mp.cfg` | `fpslimit=<cap>`, `multicore=1` | SA-MP frame cap and its second-core option |

Not used, on purpose: esync/fsync (Linux kernel features), DXVK/DXVK_ASYNC (no working D3D9 on MoltenVK), `__GL_*` (NVIDIA Linux driver), `WINE_CPU_TOPOLOGY` (thread affinity isn't supported on macOS).

## Ideas not shipped yet

- **D3D9 to Metal directly**: forks of DXMT and the separate `dx9mt` project are experimenting with it. If one matures, it could remove the Vulkan/OpenGL hop entirely, and the launcher's renderer switch is the place to add it.
- **dgVoodoo2 (D3D9 to D3D11) + DXMT**: possible today, but untested with SA-MP and stacks two translation layers.
