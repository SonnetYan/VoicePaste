// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VoicePaste",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "VoicePaste",
            path: "Sources",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
