// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TrackpadClicker",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "TrackpadClicker", targets: ["TrackpadClicker"])
    ],
    targets: [
        .executableTarget(
            name: "TrackpadClicker",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices")
            ]
        ),
        .testTarget(
            name: "TrackpadClickerTests",
            dependencies: ["TrackpadClicker"]
        )
    ]
)
