// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "LookHere",
    platforms: [
        .macOS("26.0")
    ],
    targets: [
        .executableTarget(
            name: "LookHere",
            path: "Sources/LookHere",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("ApplicationServices")
            ]
        )
    ]
)