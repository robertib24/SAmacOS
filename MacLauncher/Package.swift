// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SAMPRunner",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "SAMPRunner", targets: ["SAMPRunner"]),
        .executable(name: "samp-runner", targets: ["samp-runner"]),
        .library(name: "RunnerCore", targets: ["RunnerCore"])
    ],
    targets: [
        // Everything that does real work lives here. Foundation-only so it
        // builds and is unit-tested on Linux CI as well as on macOS.
        .target(name: "RunnerCore"),

        // Command-line front end: `samp-runner setup`, `samp-runner connect ...`
        .executableTarget(name: "samp-runner", dependencies: ["RunnerCore"]),

        // SwiftUI launcher (macOS only; compiles to a stub elsewhere).
        .executableTarget(name: "SAMPRunner", dependencies: ["RunnerCore"]),

        .testTarget(name: "RunnerCoreTests", dependencies: ["RunnerCore"])
    ]
)
