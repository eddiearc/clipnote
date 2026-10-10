// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Clipnote",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "ClipnoteCore", targets: ["ClipnoteCore"])
    ],
    targets: [
        .target(
            name: "ClipnoteCore",
            path: "Sources/ClipnoteCore"
        ),
        .testTarget(
            name: "ClipnoteCoreTests",
            dependencies: ["ClipnoteCore"],
            path: "Tests/ClipnoteCoreTests"
        )
    ]
)

// AppKit / EventKit 可执行目标只在 macOS 上加入。
// Linux CI 可以编译并测试 ClipnoteCore，但无法链接 EventKit。
#if os(macOS)
package.products.append(
    .executable(name: "Clipnote", targets: ["Clipnote"])
)
package.targets.append(
    .executableTarget(
        name: "Clipnote",
        dependencies: ["ClipnoteCore"],
        path: "Sources/Clipnote"
    )
)
#endif
