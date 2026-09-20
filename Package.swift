// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "FryDayExposureCore",
    platforms: [.macOS(.v13)],
    products: [.library(name: "ExposureCore", targets: ["ExposureCore"])],
    targets: [
        .target(name: "ExposureCore", path: "Sources/Models"),
        .testTarget(name: "ExposureCoreTests", dependencies: ["ExposureCore"], path: "Tests")
    ]
)
