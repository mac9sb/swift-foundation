// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "swift-foundation",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "FoundationKit", targets: ["FoundationKit"]),
    ],
    targets: [
        .target(name: "FoundationKit"),
        .testTarget(
            name: "FoundationKitTests",
            dependencies: ["FoundationKit"]
        ),
    ]
)
