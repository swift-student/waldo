// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GitService",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "GitService",
            targets: ["GitService"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-student/swift-print-debug", from: "0.1.1"),
    ],
    targets: [
        .target(
            name: "GitService",
            dependencies: [
                .product(name: "PrintDebug", package: "swift-print-debug"),
                "Clibgit2",
            ]
        ),
        .testTarget(
            name: "GitServiceTests",
            dependencies: ["GitService"],
            linkerSettings: [
                .linkedLibrary("z"),
                .linkedLibrary("iconv")
            ]
        ),
        .binaryTarget(name: "Clibgit2", path: "Sources/Clibgit2.xcframework"),
    ]
)