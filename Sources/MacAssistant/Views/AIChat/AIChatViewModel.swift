import Foundation
import MacAssistantCore

@MainActor
final class AIChatViewModel: ObservableObject {
    @Published var state: FeaturePresentationState = .ready
    @Published var profiles: [AIProviderProfile] = []
    @Published var selectedProfileID: UUID?
    @Published var modelID = ""
    @Published var input = ""
    @Published var conversation = ChatConversation(title: "Новый диалог")
    private let ai: any AIProviding
    private let manager: any AIProfileManaging
    private let history: ChatHistoryStore
    private var requestTask: Task<Void, Never>?
    init(ai: any AIProviding, manager: any AIProfileManaging, history: ChatHistoryStore = .init()) { self.ai = ai; self.manager = manager; self.history = history }
    func load() async { profiles = await manager.profiles(); selectedProfileID = profiles.first?.id; modelID = profiles.first?.defaultModelID ?? "" }
    func send() {
        guard let profile = profiles.first(where: { $0.id == selectedProfileID }), !modelID.isEmpty, !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let user = ChatMessage(role: .user, content: input); input = ""; conversation.messages.append(user); conversation.updatedAt = .now; state = .loading
        requestTask = Task { [weak self] in guard let self else { return }; do { let reply = try await ai.send(messages: conversation.messages, using: profile, modelID: modelID); guard !Task.isCancelled else { return }; conversation.messages.append(reply); conversation.title = conversation.messages.first?.content.prefix(40).description ?? "Диалог"; conversation.updatedAt = .now; try await history.save([conversation]); state = .ready } catch is CancellationError { state = .ready } catch { state = .error(message: error.localizedDescription) } }
    }
    func cancel() { requestTask?.cancel() }
}
