import SwiftUI
import MacAssistantCore

@main
struct MacAssistantApp: App {
    /// Контейнер создаётся один раз на жизненный цикл приложения: экраны в
    /// последующих блоках будут получать зависимости через него, а не создавать сервисы сами.
    private let container = AppContainer.makeDefault()

    var body: some Scene {
        WindowGroup("Mac Assistant") {
            ContentView(container: container)
        }
        .defaultSize(width: 900, height: 620)

        // Настройки также доступны отдельным системным окном, как ожидают
        // пользователи macOS. Раздел в боковой панели остаётся обзором настроек.
        Settings {
            PreferencesView()
        }
    }
}
