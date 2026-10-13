import SwiftUI
import MacAssistantCore

struct DiagnosticsView: View {
    @StateObject private var viewModel: DiagnosticsViewModel
    @State private var showingAIConsent = false
    private let ai: any AIProviding
    private let profiles: any AIProfileManaging

    init(container: AppContainer) {
        _viewModel = StateObject(wrappedValue: DiagnosticsViewModel(diagnostics: container.services.diagnostics))
        ai = container.services.ai
        profiles = container.services.aiProfiles
    }

    var body: some View {
        FeatureScreen(title: "Диагностика", state: viewModel.state) {
            Group {
                if let report = viewModel.report {
                    List(report.findings) { finding in
                        VStack(alignment: .leading, spacing: 6) {
                            Label(finding.title, systemImage: symbol(for: finding.severity))
                                .foregroundStyle(color(for: finding.severity))
                            Text(finding.explanation)
                            Text(finding.recommendation).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .accessibilityLabel("Результаты диагностики")
                } else {
                    ContentUnavailableView(
                        "Диагностика ещё не запускалась",
                        systemImage: "stethoscope",
                        description: Text("Собираются только локальные системные показатели без прав администратора.")
                    )
                }
            }
        }
        .toolbar {
            Button("Запустить диагностику", systemImage: "play.fill") {
                Task { await viewModel.run() }
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
            .help("Запустить локальную системную диагностику")
            if viewModel.report != nil {
                Button("Подготовить для ИИ", systemImage: "sparkles") { showingAIConsent = true }
            }
        }
        .sheet(isPresented: $showingAIConsent) {
            if let report = viewModel.report { DiagnosticAIConsentView(report: report, ai: ai, profiles: profiles) }
        }
    }

private struct DiagnosticAIConsentView: View {
    @Environment(\.dismiss) private var dismiss
    let report: DiagnosticReport
    let ai: any AIProviding
    let profiles: any AIProfileManaging
    @State private var consent = false
    @State private var profile: AIProviderProfile?
    @State private var modelID = ""
    @State private var result = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Предварительный просмотр для ИИ").font(.title2)
            Text("Будет передан только показанный ниже обезличенный текст. API-ключи, серийные номера и пути файлов исключены.").foregroundStyle(.secondary)
            TextEditor(text: .constant(DiagnosticReportRedactor.text(for: report))).font(.body.monospaced()).frame(minHeight: 220)
            Toggle("Я подтверждаю передачу этого отчёта выбранному провайдеру", isOn: $consent)
            TextField("Model ID", text: $modelID)
            if !result.isEmpty { Text(result).textSelection(.enabled) }
            HStack { Spacer(); Button("Отмена") { dismiss() }; Button("Отправить") { send() }.disabled(!consent || profile == nil || modelID.isEmpty) }
        }
        .padding().frame(width: 620)
        .task { profile = await profiles.profiles().first; modelID = profile?.defaultModelID ?? "" }
    }

    private func send() {
        guard let profile else { return }
        Task { do { let reply = try await ai.send(messages: [ChatMessage(role: .system, content: "Проанализируй только предоставленный диагностический отчёт на русском языке."), ChatMessage(role: .user, content: DiagnosticReportRedactor.text(for: report))], using: profile, modelID: modelID); result = reply.content } catch { result = error.localizedDescription } }
    }
}

    private func symbol(for severity: DiagnosticSeverity) -> String {
        switch severity {
        case .info: "info.circle"
        case .warning: "exclamationmark.triangle"
        case .critical: "xmark.octagon"
        }
    }

    private func color(for severity: DiagnosticSeverity) -> Color {
        switch severity {
        case .info: .secondary
        case .warning: .orange
        case .critical: .red
        }
    }
    }
