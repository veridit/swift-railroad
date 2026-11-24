// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "swift-railroad",
    platforms: [.macOS(.v12), .iOS(.v15), .tvOS(.v15), .watchOS(.v8), .visionOS(.v1)],
    products: [
        .library(name: "Railroad", targets: ["Railroad"]),
    ],
    targets: [
        .target(
            name: "Railroad",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "RailroadTests",
            dependencies: ["Railroad"],
            exclude: ["Fixtures"]
        ),
    ]
)
