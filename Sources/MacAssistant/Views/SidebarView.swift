import SwiftUI

/// Нативный короткий список сохраняет плотность стандартной боковой панели macOS.
struct SidebarView: View {
    @Binding var selection: AppSection?

    var body: some View {
        List(selection: $selection) {
            Section("Mac Assistant") {
                ForEach(AppSection.allCases) { section in
                    if section == .agents {
                        Label {
                            Text(section.title)
                        } icon: {
                            // Авторская иконка показывает цифровую Афину — образ
                            // безопасного помощника. Ограниченный размер сохраняет
                            // нативную плотность боковой панели macOS.
                            Image("AgentAthena", bundle: .module)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        }
                        .tag(section)
                    } else {
                        Label(section.title, systemImage: section.systemImage)
                            .tag(section)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Mac Assistant")
    }
}
