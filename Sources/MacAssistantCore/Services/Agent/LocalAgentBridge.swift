import Foundation

/// Безопасный исполнитель разрешённых MCP-команд.
///
/// Важное ограничение: здесь нет запуска shell, AppleScript, передачи путей или
/// произвольных сетевых запросов. Добавление каждой новой команды требует явного
/// описания разрешения и отдельной проверки, а не передачи текста агента в систему.
public actor LocalAgentBridge: AgentBridging {
    public static let commands: [AgentCommand] = [
        AgentCommand(
            id: "system.get_info",
            title: "Сведения о Mac",
            permissionLevel: .readOnly,
            description: "Модель, версия macOS, архитектура и число ядер без серийного номера."
        ),
        AgentCommand(
            id: "system.get_metrics",
            title: "Показатели системы",
            permissionLevel: .readOnly,
            description: "Текущие CPU, память и свободное место без истории процессов."
        ),
        AgentCommand(
            id: "diagnostics.run",
            title: "Локальная диагностика",
            permissionLevel: .readOnly,
            description: "Структурированный отчёт и безопасные рекомендации, созданные локально."
        ),
        AgentCommand(
            id: "storage.get_overview",
            title: "Сводка накопителя",
            permissionLevel: .readOnly,
            description: "Общий и доступный объём системного накопителя без путей и списка файлов."
        )
    ]

    private let systemInformation: any SystemInformationProviding
    private let diagnostics: any SystemDiagnosing
    private let storage: any StorageAnalyzing
    private var tasks: [UUID: AgentTask] = [:]

    public init(
        systemInformation: any SystemInformationProviding,
        diagnostics: any SystemDiagnosing,
        storage: any StorageAnalyzing
    ) {
        self.systemInformation = systemInformation
        self.diagnostics = diagnostics
        self.storage = storage
    }

    public func availableCommands() async -> [AgentCommand] {
        Self.commands
    }

    public func execute(command request: AgentCommandRequest) async throws -> AgentCommandResult {
        guard let command = Self.commands.first(where: { $0.id == request.commandID }) else {
            throw ServiceError.invalidInput(reason: "Команда внешнего агента не входит в разрешённый список.")
        }
        guard command.permissionLevel == .readOnly else {
            throw ServiceError.unavailable(feature: "Команда требует локального согласия")
        }

        let task = AgentTask(command: command.id, status: .running)
        tasks[task.id] = task
        defer {
            // Завершённые задачи не накапливаются в памяти. Журнал аудита появится
            // отдельно после согласования политики хранения пользовательских данных.
            tasks.removeValue(forKey: task.id)
        }

        do {
            let result = try await result(for: command.id)
            return result
        } catch {
            throw error
        }
    }

    public func activeTasks() async -> [AgentTask] {
        tasks.values.sorted { $0.startedAt < $1.startedAt }
    }

    public func cancelTask(id: UUID) async {
        // Сервисы чтения не принимают идентификаторы задач для отмены. Метод остаётся
        // в контракте, чтобы будущие длительные операции могли быть отменяемыми.
        guard var task = tasks[id] else { return }
        task.status = .cancelled
        tasks[id] = task
    }

    private func result(for commandID: String) async throws -> AgentCommandResult {
        switch commandID {
        case "system.get_info":
            let info = try await systemInformation.systemInfo()
            return AgentCommandResult(
                commandID: commandID,
                text: "Mac: \(info.modelName); macOS: \(info.operatingSystemVersion); архитектура: \(info.architecture); ядер: \(info.physicalCPUCoreCount)/\(info.logicalCPUCoreCount)."
            )
        case "system.get_metrics":
            let metrics = try await systemInformation.systemMetrics()
            let cpu = metrics.cpuUsagePercent.map { String(format: "%.1f%%", $0) } ?? "подготавливается"
            return AgentCommandResult(
                commandID: commandID,
                text: "CPU: \(cpu); память: \(metrics.usedMemoryBytes)/\(metrics.totalMemoryBytes) байт; доступно на накопителе: \(metrics.availableStorageBytes) байт."
            )
        case "diagnostics.run":
            let report = try await diagnostics.runDiagnostics()
            let findings = report.findings.map(\.title).joined(separator: "; ")
            return AgentCommandResult(
                commandID: commandID,
                text: "Диагностика: \(report.status.rawValue). Находки: \(findings.isEmpty ? "нет" : findings)."
            )
        case "storage.get_overview":
            let overview = try await storage.storageOverview()
            return AgentCommandResult(
                commandID: commandID,
                text: "Накопитель: всего \(overview.totalBytes) байт, доступно \(overview.availableBytes) байт."
            )
        default:
            throw ServiceError.invalidInput(reason: "Неизвестная команда.")
        }
    }
}
