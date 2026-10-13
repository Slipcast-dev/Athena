import SwiftUI
import MacAssistantCore

struct AIChatView: View {
    @StateObject private var viewModel: AIChatViewModel
    init(container: AppContainer) { _viewModel = StateObject(wrappedValue: AIChatViewModel(ai: container.services.ai, manager: container.services.aiProfiles)) }
    var body: some View {
        FeatureScreen(title: "ИИ-помощник", state: viewModel.state) {
            VStack(spacing: 12) {
                if viewModel.profiles.isEmpty { ContentUnavailableView("Подключите ИИ-провайдера", systemImage: "bubble.left.and.bubble.right", description: Text("Добавьте профиль в разделе «ИИ-провайдеры».")) }
                else { ScrollView { LazyVStack(alignment: .leading, spacing: 12) { ForEach(viewModel.conversation.messages) { message in VStack(alignment: message.role == .user ? .trailing : .leading) { Text(message.role == .user ? "Вы" : "ИИ").font(.caption).foregroundStyle(.secondary); Text(message.content).textSelection(.enabled).padding(8).background(.quaternary, in: RoundedRectangle(cornerRadius: 8)) }.frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading) } }.padding() }
                    HStack { Picker("Профиль", selection: $viewModel.selectedProfileID) { ForEach(viewModel.profiles) { Text($0.name).tag(Optional($0.id)) } }.frame(width: 180); TextField("Model ID", text: $viewModel.modelID); TextField("Сообщение", text: $viewModel.input, axis: .vertical); Button("Отправить") { viewModel.send() }.disabled(viewModel.input.isEmpty || viewModel.modelID.isEmpty) }
                }
            }.padding()
        }
        .toolbar { if viewModel.state == .loading { Button("Остановить", systemImage: "stop.fill") { viewModel.cancel() } } }
        .task { await viewModel.load() }
    }
}
