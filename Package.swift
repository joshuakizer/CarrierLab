// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CarrierLab",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "CarrierLab",
            targets: ["CarrierLab"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "CarrierLab",
            dependencies: [],
            path: "Sources/CarrierLab"
        ),
        .testTarget(
            name: "CarrierLabTests",
            dependencies: ["CarrierLab"],
            path: "Tests/CarrierLabTests"
        )
    ]
)
