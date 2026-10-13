import Foundation
import MacAssistantCore

/// Состояние запуска диагностики изолировано от представления и от конкретного
/// источника отчёта, поэтому сервис можно заменить тестовой реализацией.
@MainActor
final class DiagnosticsViewModel: ObservableObject {
    @Published private(set) var state: FeaturePresentationState = .ready
    @Published private(set) var report: DiagnosticReport?
    private let diagnostics: any SystemDiagnosing

    init(diagnostics: any SystemDiagnosing) {
        self.diagnostics = diagnostics
    }

    func run() async {
        state = .loading
        do {
            report = try await diagnostics.runDiagnostics()
            state = .ready
        } catch is CancellationError {
            state = .ready
        } catch {
            state = .error(message: error.localizedDescription)
        }
    }
}
