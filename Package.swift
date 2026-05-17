// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "VoiceInteractionMac",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "VoiceInteractionMac", targets: ["VoiceInteractionMac"]),
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/argmax-oss-swift.git", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "VoiceInteractionMac",
            dependencies: [
                .product(name: "WhisperKit", package: "argmax-oss-swift"),
            ]
        ),
    ]
)
