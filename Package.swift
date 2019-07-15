// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AsyncSequence",
    products: [
        .library(name: "AsyncSequence", targets: ["AsyncSequence"]),
    ],
    dependencies: [],
    targets: [
        .target(name: "AsyncSequence", dependencies: []),
        .testTarget(name: "AsyncSequenceTests", dependencies: ["AsyncSequence"]),
    ]
)