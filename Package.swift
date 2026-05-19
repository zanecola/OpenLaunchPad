// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenLaunchPad",
    platforms: [.macOS("26.0")],
    targets: [
        .executableTarget(
            name: "OpenLaunchPad",
            path: "Sources/OpenLaunchPad",
            linkerSettings: [
                .linkedFramework("Carbon")  // for RegisterEventHotKey global shortcut
            ]
        ),
        .testTarget(
            name: "OpenLaunchPadTests",
            dependencies: ["OpenLaunchPad"]
        )
    ]
)
