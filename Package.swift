// swift-tools-version: 5.9
// Минимальная конфигурация Swift Package: она делает архитектурное ядро
// воспроизводимо собираемым и тестируемым без сторонних зависимостей.
import PackageDescription

let package = Package(
    name: "MacAssistant",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "MacAssistantCore", targets: ["MacAssistantCore"]),
        .executable(name: "MacAssistant", targets: ["MacAssistant"])
    ],
    targets: [
        .target(name: "MacAssistantCore"),
        .executableTarget(
            name: "MacAssistant",
            dependencies: ["MacAssistantCore"]
        ),
        .testTarget(
            name: "MacAssistantCoreTests",
            dependencies: ["MacAssistantCore"]
        )
    ]
)
