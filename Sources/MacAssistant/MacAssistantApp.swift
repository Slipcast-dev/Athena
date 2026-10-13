import SwiftUI
import MacAssistantCore

@main
struct MacAssistantApp: App {
    /// Контейнер создаётся один раз на жизненный цикл приложения: экраны в
    /// последующих блоках будут получать зависимости через него, а не создавать сервисы сами.
    private let container = AppContainer.makeDefault()

    var body: some Scene {
        WindowGroup("Mac Assistant") {
            ArchitecturePlaceholderView(container: container)
        }
        .defaultSize(width: 900, height: 620)
    }
}

private struct ArchitecturePlaceholderView: View {
    let container: AppContainer

    var body: some View {
        ContentUnavailableView(
            "Mac Assistant",
            systemImage: "desktopcomputer",
            description: Text("Архитектурная основа подготовлена. Навигация появится в следующем блоке.")
        )
    }
}
