// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Diffi",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "Diffi",
            targets: ["Diffi"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.7.0"),
    ],
    targets: [
        .target(
            name: "Diffi",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                "Clibgit2",
            ]
        ),
        .binaryTarget(name: "Clibgit2", path: "Sources/Clibgit2.xcframework"),
    ]
)

