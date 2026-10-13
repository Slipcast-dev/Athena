import SwiftUI
import MacAssistantCore

struct AgentsView: View {
    let container: AppContainer
    @State private var commands: [AgentCommand] = []

    var body: some View {
        FeatureScreen(title: "Агенты", state: .ready) {
            List {
                Section("DeepSeek Harness") {
                    Label("Локальный MCP-мост готов", systemImage: "checkmark.shield")
                    Text("Доступны только команды чтения. Мост не запускает shell, не меняет файлы и не отправляет данные в сеть.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Section("Разрешённые команды") {
                    ForEach(commands) { command in
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
                commands = await container.services.agentBridge.availableCommands()
            }
        }
    }
}
