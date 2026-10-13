import Foundation
import MacAssistantCore

@MainActor
final class ProvidersViewModel: ObservableObject {
    @Published private(set) var profiles: [AIProviderProfile] = []
    @Published var error: String?
    private let manager: any AIProfileManaging
    init(manager: any AIProfileManaging) { self.manager = manager }
    func reload() async { profiles = await manager.profiles() }
    func save(name: String, kind: AIProviderKind, url: String, key: String) async {
        guard let baseURL = URL(string: url) else { error = "Укажите корректный адрес API."; return }
        do { try await manager.save(profile: AIProviderProfile(name: name, kind: kind, baseURL: baseURL), apiKey: key); await reload() }
        catch { self.error = error.localizedDescription }
    }
    func delete(_ profile: AIProviderProfile) async { do { try await manager.delete(profileID: profile.id); await reload() } catch { self.error = error.localizedDescription } }
}
