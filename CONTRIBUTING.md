# Contributing

## Development setup

Requirements: macOS 13+ and Xcode 15+ (or the Command Line Tools). Homebrew isn't needed.

```bash
git clone https://github.com/robertib24/SAmacOS.git
cd SAmacOS
./scripts/test.sh            # unit + integration tests
./scripts/run-dev.sh         # run the SwiftUI app from source
./scripts/run-dev.sh doctor  # run any samp-runner command from source
./scripts/build.sh           # build/SA-MP Runner.app + build/samp-runner
```

To experiment without touching your real install, point everything at a scratch folder:

```bash
SAMP_RUNNER_HOME=/tmp/samp-test ./scripts/run-dev.sh setup
```

## Where code goes

- **`MacLauncher/Sources/RunnerCore`**: all behaviour. Foundation only (no AppKit/SwiftUI), so it builds and is tested on Linux too. Add a test in `Tests/RunnerCoreTests` for anything you change here. `RunnerIntegrationTests` shows how to drive the full flow against a fake `wine`.
- **`MacLauncher/Sources/samp-runner`**: the CLI, a thin layer over `Runner`.
- **`MacLauncher/Sources/SAMPRunner`**: the SwiftUI app, a thin layer over `Runner`. All Wine work goes through `LauncherModel`'s serial queue.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Performance changes

Any change that claims to make the game faster should come with numbers. Turn on Benchmark mode, play the same route before and after, and include both results (average FPS, 1% low, Mac model, renderer) in the pull request. Only use Wine/MoltenVK options you can point to in their source or docs. The 1.x launcher accumulated many that did nothing on macOS.

## Bug reports

Include:
- Mac model, RAM, macOS version
- the output of `samp-runner doctor` (or **Diagnostics › Copy Report**)
- the game log from `~/Library/Application Support/SA-MP Runner/logs/`, ideally from a run with `--verbose`

## Ideas that would help

- Testing the Vulkan vs OpenGL renderers on more Macs and sharing benchmark numbers
- A Metal-native Direct3D 9 path (see "Ideas not shipped yet" in [docs/PERFORMANCE.md](docs/PERFORMANCE.md))
- An app icon
- Notarized release builds
