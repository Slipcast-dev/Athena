import Foundation

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
            return contents.contains("id: mcp-mac-assistant") ? .configured : .notConfigured
        }
    }

    public func connect(_ client: MCPClient) async throws -> MCPConnectionStatus {
        guard let executable = executableLocator(), fileManager.isExecutableFile(atPath: executable.path) else {
            return .unavailable(reason: "MCP-исполнитель приложения не найден. Переустановите Mac Assistant.")
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
        let existing = (try? String(contentsOf: patchURL, encoding: .utf8)) ?? ""

        // Не переписываем настройки Harness и не трогаем уже существующую запись.
        guard !existing.contains("id: mcp-mac-assistant") else { return }
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
        let separator = existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : "\n"
        try (existing + separator + patch + "\n").write(to: patchURL, atomically: true, encoding: .utf8)
    }

    private func disconnectHarness() throws {
        let patchURL = harnessPatchURL
        guard let existing = try? String(contentsOf: patchURL, encoding: .utf8) else { return }
        let marker = "- insert:\n    - id: mcp-mac-assistant"
        guard let start = existing.range(of: marker) else { return }

        // Одна операция `insert` в cordis.patch.yml начинается с `-` в первом
        // столбце. Поэтому граница следующей такой операции позволяет удалить
        // только блок, который создаёт Mac Assistant, не затрагивая остальные
        // записи пользователя в том же файле.
        let followingRange = existing.range(of: "\n- ", range: start.upperBound..<existing.endIndex)
        let end = followingRange?.lowerBound ?? existing.endIndex
        var updated = String(existing[..<start.lowerBound]) + String(existing[end...])
        updated = updated.trimmingCharacters(in: .whitespacesAndNewlines)

        if updated.isEmpty {
            // Файл был создан только для Mac Assistant, поэтому его безопасно
            // убрать целиком. Это возвращает Harness в исходное состояние.
            try fileManager.removeItem(at: patchURL)
        } else {
            try (updated + "\n").write(to: patchURL, atomically: true, encoding: .utf8)
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

public enum MCPConnectionError: LocalizedError, Sendable {
    case codexRegistrationFailed(message: String)

    public var errorDescription: String? {
        switch self {
        case let .codexRegistrationFailed(message):
            return message.isEmpty ? "Codex не смог зарегистрировать MCP-исполнитель." : "Codex не смог зарегистрировать MCP-исполнитель: \(message)"
        }
    }
}
