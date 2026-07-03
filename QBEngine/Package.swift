// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "QBEngine",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "QBEngine", targets: ["QBEngine"]),
        .executable(name: "qbengine-cli", targets: ["QBEngineCLI"])
    ],
    targets: [
        .target(name: "QBEngine"),
        .executableTarget(name: "QBEngineCLI", dependencies: ["QBEngine"]),
        .testTarget(name: "QBEngineTests", dependencies: ["QBEngine"])
    ]
)