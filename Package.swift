// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ClaudeMonitor",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "ClaudeMonitor",
            path: "Sources/ClaudeMonitor"
        ),
    ]
)
