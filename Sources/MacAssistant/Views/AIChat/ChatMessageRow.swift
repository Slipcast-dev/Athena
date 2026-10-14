import SwiftUI
import MacAssistantCore
import AppKit

/// Пользовательский вопрос выровнен вправо; ответ читается как документ.
/// Содержимое всегда отображается как текст: модель не может выполнить HTML.
struct ChatMessageRow: View {
    let message: ChatMessage
    let isGenerating: Bool

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .top, spacing: ChatStyle.gap) {
            if isUser { Spacer(minLength: ChatStyle.sectionGap) }
            if !isUser {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 32, height: 32)
                    .background(ChatStyle.softSurface, in: Circle())
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: ChatStyle.smallGap) {
                if !isUser {
                    HStack(spacing: ChatStyle.smallGap) {
                        Text("Mac Assistant").font(.subheadline.weight(.semibold))
                        if isGenerating {
                            ProgressView().controlSize(.small)
                            Text("Отвечает…").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                if !message.content.isEmpty {
                    Text(message.content)
                        .font(ChatStyle.bodyFont).lineSpacing(5)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if !isGenerating {
                    Text("Ответ не получен.").foregroundStyle(.secondary)
                }
                if !isUser && !isGenerating && !message.content.isEmpty {
                    Button {
                        // Clipboard меняется только по явному действию пользователя.
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(message.content, forType: .string)
                    } label: {
                        Label("Скопировать ответ", systemImage: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless).foregroundStyle(.secondary)
                    .help("Скопировать ответ")
                }
            }
            .padding(isUser ? ChatStyle.gap : 0)
            .background {
                if isUser { RoundedRectangle(cornerRadius: ChatStyle.bubbleRadius).fill(ChatStyle.softSurface) }
            }
            if !isUser { Spacer(minLength: 0) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(isUser ? "Вы" : "Mac Assistant")
    }
}
