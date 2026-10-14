import Foundation
import MacAssistantCore

/// Минимальный сервер MCP поверх stdio для DeepSeek Harness.
///
/// Поток stdout является частью протокола, поэтому в него никогда не выводятся
/// отладочные сообщения. Ошибки также кодируются в JSON-RPC-ответ, чтобы Harness
/// не получил случайный текст вместо сообщения протокола.
@main
struct MacAssistantMCP {
    static func main() async {
        let systemInformation = SystemInformationService()
        let bridge = LocalAgentBridge(
            systemInformation: systemInformation,
            diagnostics: SystemDiagnosticsService(systemInformation: systemInformation),
            storage: StorageAnalysisService()
        )
        let server = MCPStdioServer(bridge: bridge)
        await server.run()
    }
}

/// Сервер поддерживает только подмножество MCP, которое необходимо Harness:
/// рукопожатие, выдачу инструментов и вызов инструмента. Все инструменты имеют
/// пустую схему входных данных, поэтому агент не может передать путь, shell-код
/// или иной недоверенный параметр.
actor MCPStdioServer {
    private let bridge: any AgentBridging

    init(bridge: any AgentBridging) {
        self.bridge = bridge
    }

    func run() async {
        while let line = readLine(strippingNewline: true) {
            guard let data = line.data(using: .utf8),
                  let request = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                write(error: .parseError, id: nil)
                continue
            }
            await handle(request: request)
        }
    }

    private func handle(request: [String: Any]) async {
        let identifier = request["id"]
        guard let method = request["method"] as? String else {
            write(error: .invalidRequest, id: identifier)
            return
        }

        // Уведомления MCP не имеют id и не нуждаются в ответе.
        if method == "notifications/initialized" { return }

        switch method {
        case "initialize":
            write(result: [
                "protocolVersion": "2024-11-05",
                "capabilities": ["tools": [:]],
                "serverInfo": ["name": "mac-assistant", "version": "0.1.5"]
            ], id: identifier)
        case "tools/list":
            let commands = await bridge.availableCommands()
            let tools = commands.map { command in
                [
                    "name": command.id,
                    "description": command.description,
                    // Команды чтения параметров не принимают — это намеренная граница безопасности.
                    "inputSchema": ["type": "object", "properties": [:]]
                ] as [String: Any]
            }
            write(result: ["tools": tools], id: identifier)
        case "tools/call":
            guard let parameters = request["params"] as? [String: Any],
                  let name = parameters["name"] as? String
            else {
                write(error: .invalidParams, id: identifier)
                return
            }
            do {
                let result = try await bridge.execute(command: AgentCommandRequest(commandID: name))
                write(result: [
                    "content": [["type": "text", "text": result.text]],
                    "isError": false
                ], id: identifier)
            } catch {
                // Текст ошибки возвращается как результат инструмента, поэтому Harness
                // может объяснить отказ, не интерпретируя его как сбой транспорта.
                write(result: [
                    "content": [["type": "text", "text": error.localizedDescription]],
                    "isError": true
                ], id: identifier)
            }
        default:
            write(error: .methodNotFound, id: identifier)
        }
    }

    private func write(result: [String: Any], id: Any?) {
        var response: [String: Any] = ["jsonrpc": "2.0", "result": result]
        if let id { response["id"] = id } else { response["id"] = NSNull() }
        write(response)
    }

    private func write(error: MCPError, id: Any?) {
        var response: [String: Any] = [
            "jsonrpc": "2.0",
            "error": ["code": error.code, "message": error.message]
        ]
        if let id { response["id"] = id } else { response["id"] = NSNull() }
        write(response)
    }

    private func write(_ object: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let line = String(data: data, encoding: .utf8)
        else { return }
        FileHandle.standardOutput.write(Data((line + "\n").utf8))
    }
}

private enum MCPError {
    case parseError
    case invalidRequest
    case methodNotFound
    case invalidParams

    var code: Int {
        switch self {
        case .parseError: -32700
        case .invalidRequest: -32600
        case .methodNotFound: -32601
        case .invalidParams: -32602
        }
    }

    var message: String {
        switch self {
        case .parseError: "Некорректный JSON."
        case .invalidRequest: "Некорректный JSON-RPC запрос."
        case .methodNotFound: "Метод MCP не поддерживается."
        case .invalidParams: "Некорректные параметры MCP."
        }
    }
}
