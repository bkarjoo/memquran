// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MemQuran",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .executable(
            name: "MemQuran",
            targets: ["MemQuran"]
        )
    ],
    targets: [
        .executableTarget(
            name: "MemQuran",
            resources: [
                .copy("surah_1_al-fatiha.json")
            ]
        )
    ]
)
