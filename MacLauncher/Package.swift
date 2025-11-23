// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SA-MP Runner",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .executable(
            name: "SA-MP Runner",
            targets: ["SAMPRunner"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "SAMPRunner",
            dependencies: [],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
