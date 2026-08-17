// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Sentry",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "Sentry",
            targets: ["Sentry"]
        )
    ],
    targets: [
        .executableTarget(
            name: "Sentry",
            dependencies: [],
            path: "Sources/Sentry",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("IOKit")
            ]
        )
    ]
)
