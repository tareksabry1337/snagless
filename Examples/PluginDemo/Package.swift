// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginDemo",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../.."),
        .package(path: "../Shop"),
    ],
    targets: [
        .target(name: "Profile"),
        .target(
            name: "DemoApp",
            dependencies: ["Profile", .product(name: "Shop", package: "Shop")],
            plugins: [.plugin(name: "SnaglessPlugin", package: "snagless")]
        ),
    ],
    swiftLanguageModes: [.v6]
)
