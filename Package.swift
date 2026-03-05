// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CCMac",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "CCMac", targets: ["CCMac"])
    ],
    targets: [
        .executableTarget(
            name: "CCMac",
            path: "Sources/CCMac",
            exclude: ["Resources/Info.plist"],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
