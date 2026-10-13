import SwiftUI
import MacAssistantCore

struct ProvidersView: View {
    @StateObject private var viewModel: ProvidersViewModel
    @State private var showingEditor = false
    init(container: AppContainer) { _viewModel = StateObject(wrappedValue: ProvidersViewModel(manager: container.services.aiProfiles)) }

    var body: some View {
        FeatureScreen(title: "ИИ-провайдеры", state: .ready) {
            if viewModel.profiles.isEmpty { ContentUnavailableView("Профили не добавлены", systemImage: "network", description: Text("Ключ API сохраняется только в Keychain.")) }
            else { List { ForEach(viewModel.profiles) { profile in Label(profile.name, systemImage: "network").contextMenu { Button("Удалить", role: .destructive) { Task { await viewModel.delete(profile) } } } } } }
        }
        .toolbar { Button("Добавить профиль", systemImage: "plus") { showingEditor = true }.keyboardShortcut("n", modifiers: [.command, .shift]) }
        .task { await viewModel.reload() }
        .sheet(isPresented: $showingEditor) { ProviderEditor { name, kind, url, key in Task { await viewModel.save(name: name, kind: kind, url: url, key: key); showingEditor = false } } }
        .alert("Ошибка профиля", isPresented: Binding(get: { viewModel.error != nil }, set: { if !$0 { viewModel.error = nil } })) { Button("OK", role: .cancel) {} } message: { Text(viewModel.error ?? "") }
    }
}

private struct ProviderEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var kind: AIProviderKind = .openAI
    @State private var url = "https://api.openai.com/v1"
    @State private var key = ""
    let save: (String, AIProviderKind, String, String) -> Void
    var body: some View {
        Form { TextField("Название", text: $name); Picker("Сервис", selection: $kind) { ForEach(AIProviderKind.allCases, id: \.self) { Text($0.rawValue).tag($0) } }; TextField("Base URL", text: $url); SecureField("API-ключ", text: $key) }
            .padding().frame(width: 420).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Сохранить") { save(name, kind, url, key) }.disabled(name.isEmpty) } }
    }
}
