import SwiftUI
import MacAssistantCore

struct AgentsView: View {
    @StateObject private var viewModel: AgentsViewModel
    @State private var connectionTarget: MCPClient?

    init(container: AppContainer) {
        _viewModel = StateObject(wrappedValue: AgentsViewModel(
            agentBridge: container.services.agentBridge,
            connections: container.services.mcpConnections
        ))
    }

    var body: some View {
        FeatureScreen(title: "Агенты", state: .ready) {
            List {
                Section("Подключение MCP") {
                    Label("Локальный MCP-мост готов", systemImage: "checkmark.shield")
                    Text("После подключения Codex или Harness смогут использовать только разрешённые команды чтения. Мост не запускает shell, не меняет файлы и не отправляет данные в сеть.")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    ForEach(MCPClient.allCases) { client in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(client.title)
                                Text(viewModel.status(for: client).title)
                                    .font(.caption)
                                    .foregroundStyle(statusColor(for: viewModel.status(for: client)))
                            }
                            Spacer()
                            Button("Подключить") {
                                connectionTarget = client
                            }
                            .disabled(viewModel.isConnecting || viewModel.status(for: client) == .configured)
                        }
                    }
                }
                Section("Разрешённые команды") {
                    ForEach(viewModel.commands) { command in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(command.title)
                            Text(command.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(command.id)
                                .font(.caption.monospaced())
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .task {
                await viewModel.load()
            }
            .confirmationDialog(
                "Подключить MCP-мост?",
                isPresented: Binding(get: { connectionTarget != nil }, set: { if !$0 { connectionTarget = nil } }),
                titleVisibility: .visible
            ) {
                if let target = connectionTarget {
                    Button("Подключить к \(target.title)") {
                        Task {
                            await viewModel.connect(target)
                            connectionTarget = nil
                        }
                    }
                }
                Button("Отмена", role: .cancel) { connectionTarget = nil }
            } message: {
                Text("Приложение зарегистрирует только собственный MCP-исполнитель Mac Assistant. Другие настройки клиента не будут изменены.")
            }
            .alert("Не удалось подключить MCP", isPresented: Binding(get: { viewModel.error != nil }, set: { if !$0 { viewModel.error = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.error ?? "")
            }
        }
    }

    private func statusColor(for status: MCPConnectionStatus) -> Color {
        switch status {
        case .configured: .green
        case .notConfigured: .secondary
        case .unavailable: .red
        }
    }
}
