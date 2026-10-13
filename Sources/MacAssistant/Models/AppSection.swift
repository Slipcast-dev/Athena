import Foundation

/// Стабильные идентификаторы разделов. Строковые значения используются только
/// для сохранения выбранного пункта в рамках окна через `SceneStorage`.
enum AppSection: String, CaseIterable, Identifiable {
    case dashboard
    case diagnostics
    case storage
    case aiChat
    case providers
    case agents
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Обзор"
        case .diagnostics: "Диагностика"
        case .storage: "Накопитель"
        case .aiChat: "ИИ-помощник"
        case .providers: "ИИ-провайдеры"
        case .agents: "Агенты"
        case .settings: "Настройки"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: "rectangle.3.group"
        case .diagnostics: "stethoscope"
        case .storage: "internaldrive"
        case .aiChat: "bubble.left.and.bubble.right"
        case .providers: "network"
        case .agents: "point.3.connected.trianglepath.dotted"
        case .settings: "gearshape"
        }
    }
}
