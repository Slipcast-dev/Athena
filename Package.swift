// swift-tools-version: 5.9
// Минимальная конфигурация Swift Package: она делает архитектурное ядро
// воспроизводимо собираемым и тестируемым; Yams разбирает YAML без эвристик строк.
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
    dependencies: [.package(url: "https://github.com/jpsim/Yams.git", exact: "6.2.2")],
    targets: [
        .target(name: "MacAssistantCore", dependencies: [.product(name: "Yams", package: "Yams")]),
        .executableTarget(
            name: "MacAssistant",
            dependencies: ["MacAssistantCore"],
            // PNG Афины доступен SwiftUI через Bundle.module и применяется в
            // интерфейсе раздела «Агенты» без обращения к внешнему пути.
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "MacAssistantMCP",
            dependencies: ["MacAssistantCore"]
        ),
        .testTarget(
            name: "MacAssistantCoreTests",
            dependencies: ["MacAssistantCore", "MacAssistant"]
        )
    ]
)
