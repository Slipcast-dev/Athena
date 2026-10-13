import SwiftUI

/// Нативный короткий список сохраняет плотность стандартной боковой панели macOS.
struct SidebarView: View {
    @Binding var selection: AppSection?

    var body: some View {
        List(selection: $selection) {
            Section("Mac Assistant") {
                ForEach(AppSection.allCases) { section in
                    Label(section.title, systemImage: section.systemImage)
                        .tag(section)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Mac Assistant")
    }
}
