import Foundation

/// Граница доступа к показателям macOS. Реализация появится в блоке диагностики,
/// а протокол уже позволяет тестировать слой представления на детерминированных данных.
public protocol SystemInformationProviding: Sendable {
    func systemInfo() async throws -> SystemInfo
    func systemMetrics() async throws -> SystemMetrics
}

public protocol SystemDiagnosing: Sendable {
    func runDiagnostics() async throws -> DiagnosticReport
}

public protocol StorageAnalyzing: Sendable {
    func storageOverview() async throws -> StorageOverview
    func scanDirectory(at url: URL) async throws -> [StorageItem]
}

public protocol AIProviding: Sendable {
    func availableModels(for profile: AIProviderProfile) async throws -> [AIModel]
    func send(messages: [ChatMessage], using profile: AIProviderProfile, modelID: String) async throws -> ChatMessage
}

public protocol AgentBridging: Sendable {
    func activeTasks() async -> [AgentTask]
    func cancelTask(id: UUID) async
}

public enum ServiceError: LocalizedError, Equatable, Sendable {
    case unavailable(feature: String)
    case invalidInput(reason: String)

    public var errorDescription: String? {
        switch self {
        case let .unavailable(feature):
            return "Функция «\(feature)» пока недоступна."
        case let .invalidInput(reason):
            return "Некорректные входные данные: \(reason)"
        }
    }
}
