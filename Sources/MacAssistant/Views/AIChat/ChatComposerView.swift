import SwiftUI

struct ChatComposerView: View {
    @Binding var input: String
    let isGenerating: Bool
    let canSend: Bool
    let isLoaded: Bool
    let send: () -> Void
    let stop: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: ChatStyle.smallGap) {
            Text("Сообщение").font(.caption.weight(.medium)).foregroundStyle(.secondary)
            ZStack(alignment: .topLeading) {
                if input.isEmpty {
                    Text("Спросите что-нибудь…")
                        .font(ChatStyle.bodyFont).foregroundStyle(.secondary)
                        .padding(.leading, 5).padding(.top, 8)
                        .allowsHitTesting(false).accessibilityHidden(true)
                }
                // TextEditor гарантирует многострочный ввод на macOS:
                // Return вставляет строку, а ⌘ Return обрабатывается кнопкой.
                TextEditor(text: $input)
                    .font(ChatStyle.bodyFont).scrollContentBackground(.hidden)
                    .frame(height: 64)
                    .focused($isFocused).disabled(!isLoaded)
                    .accessibilityLabel("Сообщение для ИИ")
            }
            HStack {
                Text(isGenerating ? "Ответ можно остановить" : "⌘ Return — отправить · Return — новая строка")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: ChatStyle.smallGap)
                if isGenerating {
                    Button(action: stop) {
                        Image(systemName: "stop.fill").frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .background(.primary, in: Circle())
                    .foregroundStyle(ChatStyle.surface)
                    .accessibilityLabel("Остановить ответ").help("Остановить ответ")
                } else {
                    Button(action: send) {
                        Image(systemName: "arrow.up").font(.system(size: 17, weight: .semibold))
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .background(canSend ? Color.primary : ChatStyle.border, in: Circle())
                    .foregroundStyle(ChatStyle.surface)
                    .disabled(!canSend)
                    .keyboardShortcut(.return, modifiers: [.command])
                    .accessibilityLabel("Отправить сообщение").help("Отправить сообщение (⌘ Return)")
                }
            }
        }
        .padding(ChatStyle.gap)
        .background(ChatStyle.softSurface, in: RoundedRectangle(cornerRadius: ChatStyle.composerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: ChatStyle.composerRadius)
                .stroke(isFocused ? Color.accentColor : ChatStyle.border, lineWidth: isFocused ? 2 : 1)
        }
    }
}
