// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "ocrtool-mcp",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "ocrtool-mcp", targets: ["OCRToolMCP"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "OCRToolMCP",
            path: "Sources/OCRToolMCP"
        )
    ]
)
