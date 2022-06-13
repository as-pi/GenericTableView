// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GenericTableView",
    defaultLocalization: "ru",
    platforms: [
        .iOS(.v10)
    ],
    products: [
        .library(
            name: "GenericTableView",
            targets: ["GenericTableView"])
    ],
    dependencies: [],
    targets: [
        .target(
           name: "GenericTableView",
           resources: [
               .process("Resources/Process"),
               .copy("Resources/Copy")]
        ),
        .testTarget(
            name: "GenericTableViewTests",
            dependencies: ["GenericTableView"])
    ]
)
