import SwiftUI
import MacAssistantCore

@main
struct MacAssistantApp: App {
    /// Контейнер создаётся один раз на жизненный цикл приложения: экраны в
    /// последующих блоках будут получать зависимости через него, а не создавать сервисы сами.
    private let container = AppContainer.makeDefault()
    /// Значение хранится в UserDefaults через AppStorage и доступно до создания
    /// первого окна, поэтому выбранная пользователем тема применяется сразу.
    @AppStorage("appearanceMode") private var appearanceMode = AppAppearance.system.rawValue

    private var preferredColorScheme: ColorScheme? {
        AppAppearance(rawValue: appearanceMode)?.colorScheme
    }

    var body: some Scene {
        WindowGroup("Mac Assistant") {
            ContentView(container: container)
                .preferredColorScheme(preferredColorScheme)
        }
        .defaultSize(width: 900, height: 620)

        // Настройки также доступны отдельным системным окном, как ожидают
        // пользователи macOS. Раздел в боковой панели остаётся обзором настроек.
        Settings {
            PreferencesView()
        }
    }
}

/// В режиме `system` SwiftUI получает `nil` и наследует текущую тему macOS.
/// Другие варианты принудительно задают оформление только внутри приложения.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Как в системе"
        case .light: "Светлая"
        case .dark: "Тёмная"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
