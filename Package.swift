// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "swift-railroad-diagrams",
    platforms: [.macOS(.v12), .iOS(.v15), .tvOS(.v15), .watchOS(.v8), .visionOS(.v1)],
    products: [
        .library(name: "Railroad", targets: ["Railroad"]),
        .library(name: "RailroadImage", targets: ["RailroadImage"]),
    ],
    targets: [
        .target(
            name: "Railroad",
            resources: [.process("Resources")]
        ),
        .target(
            name: "RailroadImage",
            dependencies: ["Railroad"]
        ),
        .testTarget(
            name: "RailroadImageTests",
            dependencies: ["RailroadImage"]
        ),
        .testTarget(
            name: "RailroadTests",
            dependencies: ["Railroad"],
            exclude: ["Fixtures"]
        ),
    ]
)
