// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PostureFix",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "PostureFix",
            path: "Sources/PostureFix"
        )
    ]
)
