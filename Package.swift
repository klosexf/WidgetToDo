// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "NotionFloatCore",
    platforms: [
        .macOS(.v14)
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
        .executableTarget(
            name: "NotionFloatCoreSmokeTests",
            dependencies: ["NotionFloatCore"],
            path: "Tests/NotionFloatCoreSmokeTests"
        )
    ]
)
