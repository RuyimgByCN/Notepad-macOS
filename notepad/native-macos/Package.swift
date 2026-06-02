// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "NotepadMac",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "NotepadMacCore", targets: ["NotepadMacCore"]),
        .executable(name: "NotepadMac", targets: ["NotepadMac"])
    ],
    targets: [
        .target(name: "NotepadMacCore"),
        .executableTarget(
            name: "NotepadMac",
            dependencies: ["NotepadMacCore"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "NotepadMacCoreTests",
            dependencies: ["NotepadMacCore"]
        )
    ]
)
