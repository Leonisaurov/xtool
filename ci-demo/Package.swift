// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CounterApp",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        // Un proyecto xtool debe tener exactamente un producto library (la app).
        .library(
            name: "CounterApp",
            targets: ["CounterApp"]
        ),
    ],
    targets: [
        .target(
            name: "CounterApp"
        ),
    ]
)
