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
        .target(
            name: "CLexillaBridge",
            path: "Sources/CLexillaBridge",
            exclude: ["module.modulemap"],
            sources: ["LexillaBridge.c"],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include")
            ],
            linkerSettings: [
                .linkedLibrary("c++"),
                .unsafeFlags(["../notepad-plus-plus/lexilla/bin/liblexilla.a"])
            ]
        ),
        .target(name: "NotepadMacCore"),
        .executableTarget(
            name: "NotepadMac",
            dependencies: ["NotepadMacCore", "CLexillaBridge"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "NotepadMacCoreTests",
            dependencies: ["NotepadMacCore"]
        ),
        .testTarget(
            name: "NotepadMacTests",
            dependencies: ["NotepadMac"]
        )
    ]
)
