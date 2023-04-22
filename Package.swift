// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "storage-change-observation",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .macCatalyst(.v16),
        .watchOS(.v9),
        .tvOS(.v16)
    ],
    products: [
        .library(
            name: "StorageChangeObservation",
            targets: ["StorageChangeObservation"]),
    ],
    dependencies: [
        // For "prerelease/1.0".
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", revision: "647c93a"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "0.1.2"),
        .package(url: "https://github.com/xnzg/testable-fruits", branch: "main"),
        .package(url: "https://github.com/xnzg/Yumi", from: "0.1.0"),
    ],
    targets: [
        .target(
            name: "StorageChangeObservation",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "TestableOSLog", package: "testable-fruits"),
                "Yumi"
            ]
        ),
        .testTarget(
            name: "StorageChangeObservationTests",
            dependencies: [
                "StorageChangeObservation",
            ]
        )
    ]
)
