// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClaudeLimit",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "ClaudeLimitCore"),
        .executableTarget(name: "ClaudeLimit", dependencies: ["ClaudeLimitCore"]),
        .testTarget(name: "ClaudeLimitCoreTests", dependencies: ["ClaudeLimitCore"]),
    ],
    swiftLanguageModes: [.v5]
)
