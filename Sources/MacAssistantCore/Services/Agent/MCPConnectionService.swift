import Foundation
import Yams

/// Настраивает только собственный локальный MCP-исполнитель Mac Assistant.
/// Сервис не принимает команду, путь или YAML от агента: все значения определены
/// приложением, а запись Harness ограничена стабильным `id`.
public actor MCPConnectionService: MCPConnectionManaging {
    private let fileManager: FileManager
    private let homeDirectory: URL
    private let executableLocator: @Sendable () -> URL?

    public init(
        fileManager: FileManager = .default,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        executableLocator: @escaping @Sendable () -> URL? = { MCPConnectionService.defaultExecutableURL() }
    ) {
        self.fileManager = fileManager
        self.homeDirectory = homeDirectory
        self.executableLocator = executableLocator
    }

    public func status(for client: MCPClient) async -> MCPConnectionStatus {
        switch client {
        case .codex:
            // Codex не предоставляет стабильный API чтения конфигурации из Swift.
            // Состояние отмечается только после успешного запуска его официального CLI.
            return UserDefaults.standard.bool(forKey: "mcp.codex.configured") ? .configured : .notConfigured
        case .deepSeekHarness:
            let patchURL = harnessPatchURL
            guard let contents = try? String(contentsOf: patchURL, encoding: .utf8) else { return .notConfigured }
            guard let patch = try? HarnessPatch(contents) else {
                return .unavailable(reason: "Некорректный YAML Harness. Файл оставлен без изменений.")
            }
            return patch.containsAssistant ? .configured : .notConfigured
        }
    }

    public func connect(_ client: MCPClient) async throws -> MCPConnectionStatus {
        guard let executable = executableLocator(), fileManager.isExecutableFile(atPath: executable.path) else {
            return .unavailable(reason: "MCP-исполнитель приложения не найден. Переустановите Athena.")
        }

        switch client {
        case .codex:
            // Сначала удаляем только предыдущую одноимённую запись, чтобы повторное
            // нажатие было идемпотентным и не влияло на другие MCP-серверы пользователя.
            _ = try? runCodex(arguments: ["mcp", "remove", "mac-assistant"])
            _ = try runCodex(arguments: ["mcp", "add", "mac-assistant", "--", executable.path])
            UserDefaults.standard.set(true, forKey: "mcp.codex.configured")
            return .configured
        case .deepSeekHarness:
            try connectHarness(executable: executable)
            return .configured
        }
    }

    public func disconnect(_ client: MCPClient) async throws -> MCPConnectionStatus {
        switch client {
        case .codex:
            // Удаляется только сервер с нашим фиксированным именем. Команда не
            // получает ни путь, ни параметры от UI или внешнего агента.
            _ = try runCodex(arguments: ["mcp", "remove", "mac-assistant"])
            UserDefaults.standard.set(false, forKey: "mcp.codex.configured")
        case .deepSeekHarness:
            try disconnectHarness()
        }
        return .notConfigured
    }

    private var harnessPatchURL: URL {
        homeDirectory.appendingPathComponent(".dsh/cordis.patch.yml", isDirectory: false)
    }

    private func connectHarness(executable: URL) throws {
        let patchURL = harnessPatchURL
        let directory = patchURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let existing = fileManager.fileExists(atPath: patchURL.path)
            ? try String(contentsOf: patchURL, encoding: .utf8) : ""
        var document = try HarnessPatch(existing)

        // Не переписываем настройки Harness и не трогаем уже существующую запись.
        guard !document.containsAssistant else { return }
        let cwd = executable.deletingLastPathComponent().path.replacingOccurrences(of: "'", with: "''")
        let path = executable.path.replacingOccurrences(of: "'", with: "''")
        let patch = """
        - insert:
            - id: mcp-mac-assistant
              name: '@deepseek-ai/dsh-mcp-client'
              config:
                serverName: mac-assistant
                transport: stdio
                command: '\(path)'
                args: []
                env: {}
                cwd: '\(cwd)'
                toolCallTimeoutMs: 60000
                failOnStartupError: true
        """
        let addition = try HarnessPatch(patch)
        document.operations.append(contentsOf: addition.operations)
        try document.serialized().write(to: patchURL, atomically: true, encoding: .utf8)
    }

    private func disconnectHarness() throws {
        let patchURL = harnessPatchURL
        guard fileManager.fileExists(atPath: patchURL.path) else { return }
        var document = try HarnessPatch(String(contentsOf: patchURL, encoding: .utf8))
        guard document.containsAssistant else { return }
        document.removeAssistant()

        if document.operations.isEmpty {
            // Файл был создан только для Mac Assistant, поэтому его безопасно
            // убрать целиком. Это возвращает Harness в исходное состояние.
            try fileManager.removeItem(at: patchURL)
        } else {
            try document.serialized().write(to: patchURL, atomically: true, encoding: .utf8)
        }
    }

    private func runCodex(arguments: [String]) throws -> String {
        let process = Process()
        let output = Pipe()
        let errorOutput = Pipe()
        // `/usr/bin/env codex` использует пользовательский PATH, но не даёт
        // внешнему вводу повлиять на исполняемый файл или его аргументы.
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["codex"] + arguments
        process.standardOutput = output
        process.standardError = errorOutput
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(data: errorOutput.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw MCPConnectionError.codexRegistrationFailed(message: message.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }

    /// Публичность нужна только потому, что метод участвует в значении по
    /// умолчанию публичного инициализатора; это не делает его MCP-командой.
    public static func defaultExecutableURL() -> URL? {
        let bundleURL = Bundle.main.bundleURL
        let bundled = bundleURL.appendingPathComponent("Contents/MacOS/MacAssistantMCP")
        if FileManager.default.isExecutableFile(atPath: bundled.path) { return bundled }
        // SwiftPM-разработка хранит оба исполняемых файла в одном каталоге.
        return Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent("MacAssistantMCP")
    }
}

/// Работаем с YAML-узлами, чтобы сохранить типы и значения соседних настроек.
/// Форматирование нормализуется сериализатором; поиск по подстроке не используется.
private struct HarnessPatch {
    var operations: [Node]
    private static let assistantID = "mcp-mac-assistant"

    init(_ text: String) throws {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            operations = []
            return
        }
        // Yams хранит ошибки итерации отдельно: их нельзя потерять через Array(...).
        var parser = try Yams.compose_all(yaml: text)
        var documents: [Node] = []
        while let node = parser.next() { documents.append(node) }
        if let error = parser.error { throw error }
        guard documents.count == 1, let sequence = documents.first?.sequence else {
            throw ServiceError.invalidInput(reason: "Ожидается один YAML-список операций Harness.")
        }
        operations = Array(sequence)
        for operation in operations {
            try Self.validateUniqueKeys(operation)
            guard operation.mapping != nil else {
                throw ServiceError.invalidInput(reason: "Операция Harness должна быть YAML-объектом.")
            }
            if let insert = operation["insert"], insert.sequence == nil {
                throw ServiceError.invalidInput(reason: "insert Harness должен содержать список.")
            }
        }
    }

    /// Дубли ключей делают ID неоднозначным; безопаснее отказать в записи,
    /// чем выбрать один из конфликтующих ID и удалить чужую запись.
    private static func validateUniqueKeys(_ node: Node) throws {
        if let mapping = node.mapping {
            var keys = Set<Node>()
            for pair in mapping {
                guard keys.insert(pair.key).inserted else {
                    throw ServiceError.invalidInput(reason: "Повторяющиеся ключи YAML Harness.")
                }
                try validateUniqueKeys(pair.value)
            }
        } else if let sequence = node.sequence {
            for child in sequence { try validateUniqueKeys(child) }
        }
    }

    var containsAssistant: Bool {
        operations.contains { operation in
            operation["insert"]?.sequence?.contains { $0["id"]?.string == Self.assistantID } == true
        }
    }

    mutating func removeAssistant() {
        operations = operations.compactMap { operation in
            guard let entries = operation["insert"]?.sequence else { return operation }
            let retained = entries.filter { $0["id"]?.string != Self.assistantID }
            guard retained.count != entries.count else { return operation }
            var updated = operation
            // Если в операции есть другие ключи, сохраняем их даже при пустом insert.
            if retained.isEmpty, operation.mapping?.count == 1 { return nil }
            updated["insert"] = Node.sequence(Node.Sequence(retained))
            return updated
        }
    }

    func serialized() throws -> String {
        try Yams.serialize(node: Node.sequence(Node.Sequence(operations)))
    }
}

public enum MCPConnectionError: LocalizedError, Sendable {
    case codexRegistrationFailed(message: String)

    public var errorDescription: String? {
        switch self {
        case let .codexRegistrationFailed(message):
            return message.isEmpty ? "Codex не смог зарегистрировать MCP-исполнитель." : "Codex не смог зарегистрировать MCP-исполнитель: \(message)"
        }
    }
}
