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
                .linkedLibrary("c++")
            ]
        ),
        .target(
            name: "CBoostRegexBridge",
            path: "Sources/CBoostRegexBridge",
            sources: ["BoostRegexBridge.cpp"],
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("include"),
                .define("BOOST_REGEX_STANDALONE"),
                .unsafeFlags(["-I", "upstream/notepad-plus-plus/boostregex"])
            ],
            linkerSettings: [
                .linkedLibrary("c++")
            ]
        ),
        .target(name: "NotepadMacCore", dependencies: ["CBoostRegexBridge"]),
        .executableTarget(
            name: "NotepadMac",
            dependencies: ["NotepadMacCore", "CLexillaBridge"],
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-force_load", "-Xlinker", "upstream/notepad-plus-plus/lexilla/bin/liblexilla.a"])
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
    ],
    cxxLanguageStandard: .cxx17
)
