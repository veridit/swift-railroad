// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "swift-railroad",
    platforms: [.macOS(.v13), .iOS(.v16)],
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
