import SwiftUI
import MacAssistantCore

struct AIChatView: View {
    @StateObject private var viewModel: AIChatViewModel
    @State private var showingModelSettings = false
    @State private var followsLatest = true
    private let openProviders: () -> Void

    init(container: AppContainer, openProviders: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: AIChatViewModel(ai: container.services.ai, manager: container.services.aiProfiles))
        self.openProviders = openProviders
    }

    /// Инъекция модели используется для локального UI-тестирования без сети.
    init(viewModel: AIChatViewModel, openProviders: @escaping () -> Void = {}) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.openProviders = openProviders
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if !viewModel.isLoaded {
                Spacer()
                ProgressView("Загрузка диалогов…")
                Spacer()
            } else if viewModel.conversation.messages.isEmpty {
                welcome
            } else {
                transcript
            }
            VStack(spacing: ChatStyle.smallGap) {
                recovery
                ChatComposerView(input: $viewModel.input, isGenerating: viewModel.isGenerating,
                                 canSend: viewModel.canSend, isLoaded: viewModel.isLoaded,
                                 send: viewModel.send, stop: viewModel.cancel)
                Text("ИИ может ошибаться. Проверяйте важную информацию.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: ChatStyle.columnWidth)
            .padding(.horizontal, ChatStyle.pageInset)
            .padding(.bottom, ChatStyle.gap)
            .frame(maxWidth: .infinity)
        }
        .background(ChatStyle.surface)
        .navigationTitle("ИИ-помощник")
        .task { await viewModel.load() }
    }

    private var header: some View {
        HStack(spacing: ChatStyle.gap) {
            Button { showingModelSettings.toggle() } label: {
                HStack(spacing: ChatStyle.smallGap) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.selectedProfileName).font(.headline).lineLimit(1)
                        Text(viewModel.modelID.isEmpty ? "Выберите модель" : viewModel.modelID)
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Image(systemName: "chevron.down").font(.caption.weight(.semibold))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain).help("Выбрать провайдера и модель")
            .accessibilityLabel("Провайдер и модель: \(viewModel.selectedProfileName)")
            .disabled(viewModel.isGenerating)
            .popover(isPresented: $showingModelSettings) { modelSettings }
            Spacer(minLength: ChatStyle.smallGap)
            Menu {
                if viewModel.conversations.isEmpty { Text("Сохранённых диалогов пока нет") }
                ForEach(viewModel.conversations) { conversation in
                    Button(conversation.title) { viewModel.selectConversation(conversation.id) }
                }
            } label: {
                Label("История", systemImage: "clock.arrow.circlepath")
            }
            .menuStyle(.borderlessButton).fixedSize()
            .disabled(viewModel.isGenerating || !viewModel.isLoaded)
            Button {
                viewModel.newConversation()
            } label: {
                Image(systemName: "square.and.pencil").font(.system(size: 18))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("n", modifiers: [.command, .shift])
            .disabled(viewModel.isGenerating || !viewModel.isLoaded)
            .accessibilityLabel("Новый диалог").help("Новый диалог (⇧⌘ N)")
        }
        .padding(.horizontal, ChatStyle.pageInset).padding(.vertical, ChatStyle.smallGap)
    }

    private var modelSettings: some View {
        VStack(alignment: .leading, spacing: ChatStyle.gap) {
            Text("Провайдер и модель").font(.headline)
            if viewModel.profiles.isEmpty {
                Text("Добавьте провайдера, чтобы начать переписку.").foregroundStyle(.secondary)
            } else {
                Picker("Провайдер", selection: Binding(get: { viewModel.selectedProfileID }, set: { viewModel.selectProfile($0) })) {
                    ForEach(viewModel.profiles) { Text($0.name).tag(Optional($0.id)) }
                }
                VStack(alignment: .leading, spacing: ChatStyle.smallGap) {
                    Text("Модель").font(.caption.weight(.medium))
                    TextField("Идентификатор модели", text: $viewModel.modelID)
                        .textFieldStyle(.roundedBorder)
                }
            }
            Button("Настроить ИИ-провайдеров", systemImage: "slider.horizontal.3") {
                showingModelSettings = false
                openProviders()
            }
        }
        .padding(ChatStyle.pageInset).frame(width: 320)
    }

    private var welcome: some View {
        GeometryReader { viewport in
        ScrollView {
            VStack(spacing: ChatStyle.pageInset) {
                Image(systemName: "sparkles").font(.system(size: 36, weight: .light))
                    .accessibilityHidden(true)
                VStack(spacing: ChatStyle.smallGap) {
                    Text("Чем могу помочь?").font(ChatStyle.titleFont)
                    Text("Обсудим ваш Mac, разберём вопрос или найдём решение.")
                        .font(ChatStyle.bodyFont).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                if viewModel.profiles.isEmpty {
                    VStack(spacing: ChatStyle.smallGap) {
                        Text("Подключите ИИ-провайдера, чтобы начать чат.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Button("Подключить провайдера", action: openProviders)
                            .buttonStyle(.borderedProminent).controlSize(.large)
                    }
                } else {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: ChatStyle.smallGap) { suggestions }
                        VStack(spacing: ChatStyle.smallGap) { suggestions }
                    }
                }
            }
            .frame(maxWidth: ChatStyle.columnWidth)
            .frame(minHeight: max(0, viewport.size.height - ChatStyle.pageInset * 2))
            .padding(ChatStyle.pageInset)
            .frame(maxWidth: .infinity)
        }
        .frame(maxHeight: .infinity)
        }
    }

    private var suggestions: some View {
        ForEach(["Как понять, что замедляет Mac?", "Объясни показатели памяти", "Помоги составить план работы"], id: \.self) { prompt in
            Button { viewModel.input = prompt } label: {
                Text(prompt).font(.subheadline)
                    .padding(ChatStyle.gap)
                    .background(ChatStyle.softSurface, in: RoundedRectangle(cornerRadius: 12))
            }.buttonStyle(.plain)
        }
    }

    private var transcript: some View {
        GeometryReader { viewport in
            ScrollViewReader { reader in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: ChatStyle.sectionGap) {
                        ForEach(viewModel.conversation.messages) { message in
                            ChatMessageRow(message: message, isGenerating: viewModel.generatingMessageID == message.id)
                        }
                        Color.clear.frame(height: 1).id("chat-bottom")
                            .background(GeometryReader { marker in
                                Color.clear.preference(key: ChatBottomVisibleKey.self,
                                                       value: marker.frame(in: .named("chat-scroll")).maxY <= viewport.size.height + 80)
                            })
                    }
                    .frame(maxWidth: ChatStyle.columnWidth)
                    .padding(ChatStyle.pageInset).frame(maxWidth: .infinity)
                }
                .coordinateSpace(name: "chat-scroll")
                .onPreferenceChange(ChatBottomVisibleKey.self) { followsLatest = $0 }
                .onAppear { reader.scrollTo("chat-bottom", anchor: .bottom) }
                .onChange(of: viewModel.conversation.id) { _, _ in reader.scrollTo("chat-bottom", anchor: .bottom) }
                .onChange(of: viewModel.conversation.messages.count) { _, _ in reader.scrollTo("chat-bottom", anchor: .bottom) }
                .onChange(of: viewModel.conversation.messages.last?.content) { _, _ in
                    // Во время streaming не перетягиваем пользователя вниз,
                    // если он прокрутил ленту вверх, чтобы прочитать старый ответ.
                    if followsLatest { reader.scrollTo("chat-bottom", anchor: .bottom) }
                }
            }
        }
    }

    @ViewBuilder private var recovery: some View {
        if let error = viewModel.errorMessage {
            HStack {
                Label(error, systemImage: "exclamationmark.circle").font(.subheadline)
                Spacer(minLength: ChatStyle.smallGap)
                if viewModel.canRetry { Button("Повторить", action: viewModel.retry) }
            }.foregroundStyle(.red)
        } else if viewModel.canRetry {
            Button("Повторить незавершённый запрос", action: viewModel.retry)
        }
    }
}

private struct ChatBottomVisibleKey: PreferenceKey {
    static var defaultValue = true
    static func reduce(value: inout Bool, nextValue: () -> Bool) { value = nextValue() }
}
