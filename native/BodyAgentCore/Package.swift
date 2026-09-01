// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BodyAgentCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "BodyAgentCore", targets: ["BodyAgentCore"])
    ],
    targets: [
        .target(name: "BodyAgentCore"),
        .testTarget(name: "BodyAgentCoreTests", dependencies: ["BodyAgentCore"])
    ]
)
