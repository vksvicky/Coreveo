// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Coreveo",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "Coreveo",
            targets: ["Coreveo"]
        )
    ],
    dependencies: [
        // Add dependencies here as needed
    ],
    targets: [
        .executableTarget(
            name: "Coreveo",
            dependencies: [],
            path: "Coreveo",
            resources: [
                .process("Resources/Coreveo.png"),
                .process("Resources/Assets.xcassets")
            ]
        ),
        .testTarget(
            name: "CoreveoTests",
            dependencies: ["Coreveo"],
            path: "CoreveoTests"
        )
    ]
)
