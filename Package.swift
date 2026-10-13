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
        .executable(name: "MacAssistant", targets: ["MacAssistant"]),
        // Отдельный процесс нужен Harness для безопасного протокола stdio:
        // графическое приложение не должно делить с внешним агентом свой UI-процесс.
        .executable(name: "MacAssistantMCP", targets: ["MacAssistantMCP"])
    ],
    targets: [
        .target(name: "MacAssistantCore"),
        .executableTarget(
            name: "MacAssistant",
            dependencies: ["MacAssistantCore"]
        ),
        .executableTarget(
            name: "MacAssistantMCP",
            dependencies: ["MacAssistantCore"]
        ),
        .testTarget(
            name: "MacAssistantCoreTests",
            dependencies: ["MacAssistantCore"]
        )
    ]
)
