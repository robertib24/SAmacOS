// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SAMPRunner",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .executable(
            name: "SAMPRunner",
            targets: ["SAMPRunner"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "SAMPRunner",
            dependencies: []
        )
    ]
)
