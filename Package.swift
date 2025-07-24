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
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.20.2"),
        .package(url: "https://github.com/swift-student/swift-print-debug", from: "0.1.1"),
        .package(path: "./Git"),
    ],
    targets: [
        .target(
            name: "Diffi",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "PrintDebug", package: "swift-print-debug"),
                .product(name: "Git", package: "Git"),
            ],
            linkerSettings: [
                .linkedLibrary("z"),
                .linkedLibrary("iconv")
            ]
        ),
        .testTarget(
            name: "DiffiTests",
            dependencies: ["Diffi"]
        ),
    ]
)

