// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TrayVohaMac",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "TrayVohaMac", targets: ["TrayVohaMac"]),
    ],
    targets: [
        .executableTarget(
            name: "TrayVohaMac",
            path: "Sources/TrayVohaMac"
        ),
    ]
)
