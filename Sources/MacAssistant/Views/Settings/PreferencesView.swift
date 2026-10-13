import SwiftUI

/// Отдельная системная сцена настроек. Пока в ней нет сохраняемых параметров,
/// поэтому намеренно не создаются неиспользуемые `AppStorage`-значения.
struct PreferencesView: View {
    var body: some View {
        Form {
            Section("Mac Assistant") {
                Text("Параметры будут доступны по мере реализации модулей.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .padding()
    }
}
