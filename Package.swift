// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Stream",
    products: [
        .library(name: "Stream", targets: ["Stream"]),
    ],
    dependencies: [],
    targets: [
        .target(name: "Stream", dependencies: []),
        .testTarget(name: "StreamTests", dependencies: ["Stream"]),
    ]
)