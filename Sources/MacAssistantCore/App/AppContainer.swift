import Foundation

/// Единый объект внедрения зависимостей. Он принимает готовые сервисы вместо
/// создания их внутри экранов, поэтому UI не получает неявный доступ к системе.
@MainActor
public final class AppContainer {
    public let services: ServiceDependencies

    public init(services: ServiceDependencies) {
        self.services = services
    }

    /// Базовая конфигурация использует только локальные системные API. Сетевые,
    /// файловые и агентные сервисы остаются явно недоступными до своих блоков.
    public static func makeDefault() -> AppContainer {
        AppContainer(services: .live)
    }
}

public struct ServiceDependencies: Sendable {
    public let systemInformation: any SystemInformationProviding
    public let diagnostics: any SystemDiagnosing
    public let storage: any StorageAnalyzing
    public let ai: any AIProviding
    public let aiProfiles: any AIProfileManaging
    public let agentBridge: any AgentBridging

    public init(
        systemInformation: any SystemInformationProviding,
        diagnostics: any SystemDiagnosing,
        storage: any StorageAnalyzing,
        ai: any AIProviding,
        aiProfiles: any AIProfileManaging,
        agentBridge: any AgentBridging
    ) {
        self.systemInformation = systemInformation
        self.diagnostics = diagnostics
        self.storage = storage
        self.ai = ai
        self.aiProfiles = aiProfiles
        self.agentBridge = agentBridge
    }

    public static let unavailable = ServiceDependencies(
        systemInformation: UnavailableSystemService(),
        diagnostics: UnavailableDiagnosticsService(),
        storage: UnavailableStorageService(),
        ai: UnavailableAIService(),
        aiProfiles: UnavailableAIProfileManager(),
        agentBridge: UnavailableAgentBridge()
    )

    public static let live: ServiceDependencies = {
        let systemInformation = SystemInformationService()
        let providerManager = AIProviderManager()
        return ServiceDependencies(
            systemInformation: systemInformation,
            diagnostics: SystemDiagnosticsService(systemInformation: systemInformation),
            storage: StorageAnalysisService(),
            ai: NetworkAIProvider(manager: providerManager),
            aiProfiles: providerManager,
            agentBridge: LocalAgentBridge(
                systemInformation: systemInformation,
                diagnostics: SystemDiagnosticsService(systemInformation: systemInformation),
                storage: StorageAnalysisService()
            )
        )
    }()
}

private struct UnavailableSystemService: SystemInformationProviding {
    func systemInfo() async throws -> SystemInfo { throw ServiceError.unavailable(feature: "Системная информация") }
    func systemMetrics() async throws -> SystemMetrics { throw ServiceError.unavailable(feature: "Системные показатели") }
}

private struct UnavailableDiagnosticsService: SystemDiagnosing {
    func runDiagnostics() async throws -> DiagnosticReport { throw ServiceError.unavailable(feature: "Диагностика") }
}

private struct UnavailableStorageService: StorageAnalyzing {
    func storageOverview() async throws -> StorageOverview { throw ServiceError.unavailable(feature: "Анализ накопителя") }
    func scanDirectory(at _: URL, minimumSizeBytes _: UInt64) async throws -> [StorageItem] { throw ServiceError.unavailable(feature: "Сканирование накопителя") }
}

private struct UnavailableAIService: AIProviding {
    func availableModels(for _: AIProviderProfile) async throws -> [AIModel] { throw ServiceError.unavailable(feature: "ИИ-провайдеры") }
    func send(messages _: [ChatMessage], using _: AIProviderProfile, modelID _: String) async throws -> ChatMessage { throw ServiceError.unavailable(feature: "ИИ-чат") }
}

private struct UnavailableAIProfileManager: AIProfileManaging {
    func profiles() async -> [AIProviderProfile] { [] }
    func save(profile _: AIProviderProfile, apiKey _: String?) async throws { throw ServiceError.unavailable(feature: "ИИ-провайдеры") }
    func delete(profileID _: UUID) async throws { throw ServiceError.unavailable(feature: "ИИ-провайдеры") }
}

private actor UnavailableAgentBridge: AgentBridging {
    func availableCommands() async -> [AgentCommand] { [] }
    func execute(command _: AgentCommandRequest) async throws -> AgentCommandResult {
        throw ServiceError.unavailable(feature: "Agent Bridge")
    }
    func activeTasks() async -> [AgentTask] { [] }
    func cancelTask(id _: UUID) async {}
}
