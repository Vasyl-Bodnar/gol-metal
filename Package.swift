// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Tmp",
    products: [
        .executable(
            name: "Tmp",
            targets: ["Tmp"])
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Tmp",
            dependencies: [],
            resources: [.process("default.metallib")]),
        .testTarget(
            name: "TmpTests",
            dependencies: ["Tmp"]
        ),
    ]
)
