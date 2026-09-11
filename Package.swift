// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "JSONEditor",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "JSONEditor", path: "Sources/JSONEditor")
    ]
)
