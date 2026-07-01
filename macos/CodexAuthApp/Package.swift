// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CodexAuthApp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "CodexAuthApp", targets: ["CodexAuthApp"])
    ],
    targets: [
        .executableTarget(
            name: "CodexAuthApp"
        ),
        .testTarget(
            name: "CodexAuthAppTests",
            dependencies: ["CodexAuthApp"]
        )
    ]
)
