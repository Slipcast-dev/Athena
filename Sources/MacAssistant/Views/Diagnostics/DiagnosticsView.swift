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
    @StateObject private var viewModel: DiagnosticAIConsentViewModel

    init(report: DiagnosticReport, ai: any AIProviding, profiles: any AIProfileManaging) {
        _viewModel = StateObject(wrappedValue: DiagnosticAIConsentViewModel(report: report, ai: ai, manager: profiles))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Предварительный просмотр для ИИ").font(.title2)
            Text("Будет передан только показанный ниже обезличенный текст. API-ключи, серийные номера и пути файлов исключены.").foregroundStyle(.secondary)
            Picker("Получатель отчёта", selection: $viewModel.selectedProfileID) {
                Text("Выберите провайдера").tag(Optional<UUID>.none)
                ForEach(viewModel.profiles) { profile in
                    Text(profile.name).tag(Optional(profile.id))
                }
            }.disabled(viewModel.isSending)
            if let recipient = viewModel.selectedProfile {
                Text("Получатель: \(recipient.name)")
                Text("API: \(recipient.baseURL.absoluteString)").textSelection(.enabled).font(.caption)
            }
            TextEditor(text: .constant(viewModel.preview)).font(.body.monospaced()).frame(minHeight: 220)
            Toggle("Я подтверждаю передачу этого отчёта выбранному провайдеру", isOn: $viewModel.consent)
                .disabled(viewModel.isSending || viewModel.selectedProfile == nil)
            TextField("Model ID", text: $viewModel.modelID).disabled(viewModel.isSending)
            if viewModel.isSending { ProgressView("Отправка отчёта…") }
            if !viewModel.result.isEmpty { Text(viewModel.result).textSelection(.enabled) }
            HStack {
                Spacer()
                Button("Закрыть") { dismiss() }.disabled(viewModel.isSending)
                Button("Отправить") { Task { await viewModel.send() } }.disabled(!viewModel.canSend)
            }
        }
        .padding().frame(width: 620)
        .task { await viewModel.load() }
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
