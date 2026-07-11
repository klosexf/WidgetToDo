// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "NotionFloatCore",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "NotionFloatCore",
            targets: ["NotionFloatCore"]
        ),
        .executable(
            name: "NotionFloatCoreSmokeTests",
            targets: ["NotionFloatCoreSmokeTests"]
        )
    ],
    targets: [
        .target(
            name: "NotionFloatCore",
            path: "WidgetToDo/Core"
        ),
        .testTarget(
            name: "NotionFloatCoreTests",
            dependencies: ["NotionFloatCore"],
            path: "Tests/NotionFloatCoreTests"
        ),
        .executableTarget(
            name: "NotionFloatCoreSmokeTests",
            dependencies: ["NotionFloatCore"],
            path: "Tests/NotionFloatCoreSmokeTests"
        )
    ]
)
