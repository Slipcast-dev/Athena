import SwiftUI
import MacAssistantCore

/// Корневой экран владеет выбором раздела, поскольку он относится к конкретному
/// окну. Бизнес-операции остаются в последующих ViewModel и сервисах.
struct ContentView: View {
    let container: AppContainer
    @SceneStorage("selectedSection") private var storedSection = AppSection.dashboard.rawValue

    private var selection: Binding<AppSection?> {
        Binding(
            get: { AppSection(rawValue: storedSection) ?? .dashboard },
            set: { storedSection = ($0 ?? .dashboard).rawValue }
        )
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: selection)
        } detail: {
            DetailRouter(section: selection.wrappedValue ?? .dashboard, container: container)
        }
        .navigationSplitViewStyle(.balanced)
    }
}

private struct DetailRouter: View {
    let section: AppSection
    let container: AppContainer

    @ViewBuilder
    var body: some View {
        switch section {
        case .dashboard:
            DashboardView(container: container)
        case .diagnostics:
            DiagnosticsView(container: container)
        case .storage:
            StorageView(container: container)
        case .aiChat:
            AIChatView(container: container)
        case .providers:
            ProvidersView(container: container)
        case .agents:
            AgentsView()
        case .settings:
            SettingsOverviewView()
        }
    }
}
