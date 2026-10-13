import SwiftUI

/// Отдельная системная сцена настроек. Выбор темы сохраняется локально в
/// UserDefaults и не передаётся ИИ-провайдерам или внешним агентам.
struct PreferencesView: View {
    @AppStorage("appearanceMode") private var appearanceMode = AppAppearance.system.rawValue

    var body: some View {
        Form {
            Section("Оформление") {
                Picker("Тема", selection: $appearanceMode) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Text(appearance.title).tag(appearance.rawValue)
                    }
                }
                Text("Режим «Как в системе» автоматически следует настройке внешнего вида macOS.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .padding()
    }
}
