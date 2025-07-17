// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Diffi",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "Diffi",
            targets: ["Diffi"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.7.0")
    ],
    targets: [
        .executableTarget(
            name: "Diffi",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ]
        )
    ]
)