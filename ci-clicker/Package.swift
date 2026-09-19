// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Clicker",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "Clicker",
            targets: ["Clicker"]
        ),
    ],
    targets: [
        .target(
            name: "Clicker"
        ),
    ]
)
