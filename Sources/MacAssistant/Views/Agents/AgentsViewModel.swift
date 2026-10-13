import Foundation
import MacAssistantCore

@MainActor
final class AgentsViewModel: ObservableObject {
    @Published private(set) var commands: [AgentCommand] = []
    @Published private(set) var statuses: [MCPClient: MCPConnectionStatus] = [:]
    @Published private(set) var isUpdatingConnection = false
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
        isUpdatingConnection = true
        defer { isUpdatingConnection = false }
        do {
            statuses[client] = try await connections.connect(client)
        } catch {
            self.error = error.localizedDescription
            statuses[client] = .unavailable(reason: "Не удалось подключить")
        }
    }

    func disconnect(_ client: MCPClient) async {
        isUpdatingConnection = true
        defer { isUpdatingConnection = false }
        do {
            statuses[client] = try await connections.disconnect(client)
        } catch {
            self.error = error.localizedDescription
            statuses[client] = await connections.status(for: client)
        }
    }

    func status(for client: MCPClient) -> MCPConnectionStatus {
        statuses[client] ?? .notConfigured
    }
}
