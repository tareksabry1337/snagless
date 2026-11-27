// swift-tools-version: 6.0
import PackageDescription

let releasedBinary: Target? = .binaryTarget(
    name: "SnaglessBinary",
    url: "https://github.com/tareksabry1337/snagless/releases/download/0.10.1/snagless.artifactbundle.zip",
    checksum: "c2a920aa7c5e69646b5121103c050b879140675760f1191e972e72b38fbb83b2"
)
let buildsToolFromSource = releasedBinary == nil || Context.environment["SNAGLESS_FROM_SOURCE"] != nil
let binaryTargets = buildsToolFromSource ? [] : [releasedBinary].compactMap { $0 }

let package = Package(
    name: "Snagless",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "snagless", targets: ["snagless"]),
        .plugin(name: "SnaglessPlugin", targets: ["SnaglessPlugin"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", exact: "604.0.0")
    ],
    targets: [
        .target(name: "SnaglessModel"),
        .target(
            name: "SnaglessSyntax",
            dependencies: [
                "SnaglessModel",
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .target(name: "SnaglessAnalysis", dependencies: ["SnaglessModel"]),
        .target(name: "SnaglessDriver", dependencies: ["SnaglessModel", "SnaglessSyntax", "SnaglessAnalysis"]),
        .executableTarget(name: "snagless", dependencies: ["SnaglessDriver"]),
        .plugin(
            name: "SnaglessPlugin",
            capability: .buildTool(),
            dependencies: [.target(name: buildsToolFromSource ? "snagless" : "SnaglessBinary")]
        ),
        .testTarget(
            name: "SnaglessTests",
            dependencies: [
                "SnaglessModel",
                "SnaglessSyntax",
                "SnaglessAnalysis",
                "SnaglessDriver",
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
    ] + binaryTargets,
    swiftLanguageModes: [.v6]
)
