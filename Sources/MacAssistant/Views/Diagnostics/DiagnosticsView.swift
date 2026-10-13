import SwiftUI
import MacAssistantCore

struct DiagnosticsView: View {
    @StateObject private var viewModel: DiagnosticsViewModel

    init(container: AppContainer) {
        _viewModel = StateObject(wrappedValue: DiagnosticsViewModel(diagnostics: container.services.diagnostics))
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
