import SwiftUI
import MacAssistantCore

struct AIChatView: View {
    @StateObject private var viewModel: AIChatViewModel
    init(container: AppContainer) {
        _viewModel = StateObject(wrappedValue: AIChatViewModel(ai: container.services.ai, manager: container.services.aiProfiles))
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Picker("Диалог", selection: Binding(get: { viewModel.conversation.id }, set: { viewModel.selectConversation($0) })) {
                    if !viewModel.conversations.contains(where: { $0.id == viewModel.conversation.id }) {
                        Text("Новый диалог").tag(viewModel.conversation.id)
                    }
                    ForEach(viewModel.conversations) { Text($0.title).tag($0.id) }
                }
                Button("Новый диалог", systemImage: "plus") { viewModel.newConversation() }
            }
            .disabled(viewModel.isGenerating || !viewModel.isLoaded)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.conversation.messages) { message in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(message.role == .user ? "Вы" : "ИИ").font(.caption).foregroundStyle(.secondary)
                                if viewModel.generatingMessageID == message.id {
                                    ProgressView().controlSize(.small).accessibilityLabel("Генерация ответа")
                                }
                            }
                            Text(message.content).textSelection(.enabled).padding(8)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                        }
                        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
                    }
                }.padding()
            }
            if let error = viewModel.errorMessage {
                HStack {
                    Text(error).foregroundStyle(.red)
                    if viewModel.canRetry { Button("Повторить") { viewModel.retry() } }
                }
            } else if viewModel.canRetry {
                Button("Повторить незавершённый запрос") { viewModel.retry() }
            }
            if viewModel.profiles.isEmpty {
                Text("Добавьте профиль в разделе «ИИ-провайдеры».").foregroundStyle(.secondary)
            }
            HStack {
                Picker("Профиль", selection: $viewModel.selectedProfileID) {
                    ForEach(viewModel.profiles) { Text($0.name).tag(Optional($0.id)) }
                }.frame(width: 180)
                TextField("Model ID", text: $viewModel.modelID)
                TextField("Сообщение", text: $viewModel.input, axis: .vertical)
                Button("Отправить") { viewModel.send() }
                    .disabled(viewModel.input.isEmpty || viewModel.modelID.isEmpty || viewModel.selectedProfileID == nil)
            }
            .disabled(viewModel.isGenerating || !viewModel.isLoaded)
        }
        .padding().navigationTitle("ИИ-помощник")
        .toolbar {
            if viewModel.isGenerating { Button("Остановить", systemImage: "stop.fill") { viewModel.cancel() } }
        }
        .task { await viewModel.load() }
    }
}
