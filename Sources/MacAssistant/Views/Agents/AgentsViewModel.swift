import Foundation
import MacAssistantCore

@MainActor
final class AgentsViewModel: ObservableObject {
    @Published private(set) var commands: [AgentCommand] = []
    @Published private(set) var statuses: [MCPClient: MCPConnectionStatus] = [:]
    @Published private(set) var isConnecting = false
    @Published var error: String?

    private let agentBridge: any AgentBridging
    private let connections: any MCPConnectionManaging

    init(agentBridge: any AgentBridging, connections: any MCPConnectionManaging) {
        self.agentBridge = agentBridge
        self.connections = connections
    }

    func load() async {
        commands = await agentBridge.availableCommands()
        for client in MCPClient.allCases {
            statuses[client] = await connections.status(for: client)
        }
    }

    func connect(_ client: MCPClient) async {
        isConnecting = true
        defer { isConnecting = false }
        do {
            statuses[client] = try await connections.connect(client)
        } catch {
            self.error = error.localizedDescription
            statuses[client] = .unavailable(reason: "Не удалось подключить")
        }
    }

    func status(for client: MCPClient) -> MCPConnectionStatus {
        statuses[client] ?? .notConfigured
    }
}
