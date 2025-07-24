// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Git",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "Git",
            targets: ["Git"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-student/swift-print-debug", from: "0.1.1"),
    ],
    targets: [
        .target(
            name: "Git",
            dependencies: [
                .product(name: "PrintDebug", package: "swift-print-debug"),
                "Clibgit2",
            ]
        ),
        .testTarget(
            name: "GitTests",
            dependencies: ["Git"],
            linkerSettings: [
                .linkedLibrary("z"),
                .linkedLibrary("iconv")
            ]
        ),
        .binaryTarget(name: "Clibgit2", path: "Sources/Clibgit2.xcframework"),
    ]
)