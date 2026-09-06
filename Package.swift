// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "McNetworkMenu",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "McNetworkMenu", targets: ["McNetworkMenu"])
    ],
    targets: [
        .target(
            name: "McNetworkMenuCore",
            linkerSettings: [
                .linkedFramework("Network"),
                .linkedFramework("CoreWLAN"),
                .linkedFramework("CoreLocation"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("AppKit")
            ]
        ),
        .executableTarget(
            name: "McNetworkMenu",
            dependencies: ["McNetworkMenuCore"],
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("AppKit")
            ]
        ),
        .testTarget(
            name: "McNetworkMenuCoreTests",
            dependencies: ["McNetworkMenuCore"]
        ),
        .testTarget(
            name: "McNetworkMenuUITests",
            dependencies: ["McNetworkMenuCore"]
        )
    ]
)
