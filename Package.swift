// swift-tools-version: 5.9
import PackageDescription

// ZipBar is built as a Swift package rather than an .xcodeproj so that it
// compiles with plain Command Line Tools as well as full Xcode. `swift build`
// produces the binaries; scripts/build-app.sh wraps them into ZipBar.app.
let package = Package(
    name: "ZipBar",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ZipBarKit", targets: ["ZipBarKit"]),
        .executable(name: "ZipBar", targets: ["ZipBar"]),
        .executable(name: "zipbar-probe", targets: ["zipbar-probe"]),
    ],
    targets: [
        .target(name: "ZipBarKit"),
        .executableTarget(name: "ZipBar", dependencies: ["ZipBarKit"]),
        .executableTarget(name: "zipbar-probe", dependencies: ["ZipBarKit"]),
        .testTarget(name: "ZipBarKitTests", dependencies: ["ZipBarKit"]),
    ]
)
