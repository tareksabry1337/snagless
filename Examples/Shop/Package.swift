// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Shop",
    platforms: [.macOS(.v14)],
    products: [.library(name: "Shop", targets: ["Shop"])],
    targets: [.target(name: "Shop")],
    swiftLanguageModes: [.v6]
)
