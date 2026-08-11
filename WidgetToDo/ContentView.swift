import Combine
import AppKit
import SwiftUI

private enum AppWindowChrome {
    static let cornerRadius: CGFloat = 12
    static let defaultWidth: CGFloat = 340
    static let defaultHeight: CGFloat = 460
}

struct ContentView: View {
    @ObservedObject var rootViewModel: RootViewModel

    var body: some View {
        Group {
            switch rootViewModel.screen {
            case .loading:
                ProgressView(rootViewModel.languageStore.text(.appLoading))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .frame(width: AppWindowChrome.defaultWidth, height: AppWindowChrome.defaultHeight)
            case .welcome:
                WelcomeView(
                    onStartConfig: {
                        rootViewModel.screen = .onboarding
                    },
                    onClose: {
                        NSApp.keyWindow?.orderOut(nil)
                    }
                )
                .frame(width: AppWindowChrome.defaultWidth, height: AppWindowChrome.defaultHeight)
            case .onboarding:
                OnboardingView(
                    viewModel: rootViewModel.onboardingViewModel,
                    mode: .onboarding,
                    onBack: {
                        rootViewModel.screen = .welcome
                    },
                    onLanguageChange: rootViewModel.selectLanguage
                )
                .frame(width: AppWindowChrome.defaultWidth, height: AppWindowChrome.defaultHeight)
            case .settings:
                OnboardingView(
                    viewModel: rootViewModel.onboardingViewModel,
                mode: .settings,
                onBack: rootViewModel.returnFromSettings,
                onResetConfiguration: {
                    await rootViewModel.resetConfigurationFromSettings()
                },
                onLanguageChange: rootViewModel.selectLanguage
                )
                .frame(width: AppWindowChrome.defaultWidth, height: AppWindowChrome.defaultHeight)
            case .widget:
                widgetContent
            }
        }
        .background(
            RoundedRectangle(cornerRadius: AppWindowChrome.cornerRadius, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
        .clipShape(RoundedRectangle(cornerRadius: AppWindowChrome.cornerRadius, style: .continuous))
        .environmentObject(rootViewModel.languageStore)
        .environment(\.locale, rootViewModel.languageStore.language.locale)
        .task {
            if rootViewModel.screen == .loading {
                await rootViewModel.bootstrap()
            }
        }
    }

    private var widgetContent: some View {
        GeometryReader { geometry in
            if rootViewModel.isMiniMode {
                miniCapsuleView
                    .frame(width: MiniModeLayoutEngine.defaultMiniSize.width,
                           height: MiniModeLayoutEngine.defaultMiniSize.height)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .transition(miniModeTransition)
            } else {
                FloatingWidgetView(
                    todoViewModel: rootViewModel.todoListViewModel,
                    journalViewModel: rootViewModel.journalViewModel,
                    refreshAction: rootViewModel.refreshWorkspace,
                    bannerMessage: rootViewModel.bannerMessage,
                    bannerMessageKey: rootViewModel.bannerMessageKey,
                    activeTab: rootViewModel.miniActiveTab,
                    onActiveTabChange: { tab in
                        rootViewModel.miniActiveTab = tab
                        Task { await rootViewModel.persistMiniModeState() }
                    },
                    onCollapse: {
                        rootViewModel.collapse()
                    }
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
                .transition(miniModeTransition)
            }
        }
        .animation(.easeOut(duration: 0.25), value: rootViewModel.isMiniMode)
    }

    private var miniModeTransition: AnyTransition {
        .opacity.combined(with: .scale(scale: 0.92, anchor: .topTrailing))
    }

    private var miniCapsuleView: some View {
        Group {
            switch rootViewModel.miniActiveTab {
            case .todo:
                TodoMiniCapsuleView(
                    completedCount: completedTaskCount,
                    totalCount: rootViewModel.todoListViewModel.tasks.count,
                    onExpand: { rootViewModel.expand() },
                    onClose: { NSApp.keyWindow?.orderOut(nil) }
                )
            case .journal:
                JournalMiniCapsuleView(
                    wordCount: rootViewModel.journalViewModel.editorText.count,
                    statusMessage: rootViewModel.journalViewModel.statusMessage.map {
                        rootViewModel.languageStore.text($0)
                    },
                    onExpand: { rootViewModel.expand() },
                    onClose: { NSApp.keyWindow?.orderOut(nil) }
                )
            }
        }
    }

    private var completedTaskCount: Int {
        rootViewModel.todoListViewModel.tasks.filter(\.isDone).count
    }
}

@MainActor
final class RootViewModel: ObservableObject {
    enum Screen {
        case loading
        case welcome
        case onboarding
        case settings
        case widget
    }

    @Published var screen: Screen = .loading
    @Published var bannerMessage: AppMessage?
    @Published var bannerMessageKey: AppText.Key?
    @Published var isMiniMode: Bool = false
    @Published var miniActiveTab: MiniActiveTab = .todo

    let languageStore = LanguageStore.shared

    private var screenBeforeSettings: Screen = .widget
    private var cancellables = Set<AnyCancellable>()
    private let repository: NotionRepository
    weak var windowManager: FloatingWindowManager?

    let onboardingViewModel: OnboardingViewModel
    let todoListViewModel: TodoListViewModel
    let journalViewModel: JournalViewModel

    init(repository: NotionRepository, openURL: @escaping @MainActor (URL) -> Void) {
        self.repository = repository
        todoListViewModel = TodoListViewModel(repository: repository, hasPriorityField: true, openURL: openURL)
        journalViewModel = JournalViewModel(repository: repository, openURL: openURL)
        onboardingViewModel = OnboardingViewModel(repository: repository)
        languageStore.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        onboardingViewModel.didFinishSetup = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let snapshot = try? await self.onboardingViewModel.loadSnapshot() {
                    self.todoListViewModel.configure(choiceField: snapshot.choiceField)
                }
                await self.refreshWorkspace()
            }
        }
    }

    func applyMiniModeState(_ state: MiniModeState) {
        isMiniMode = state.isMiniMode
        miniActiveTab = state.activeTab
        windowManager?.setInitialState(isMiniMode: state.isMiniMode, normalFrame: state.normalFrame)
    }

    func collapse() {
        guard !isMiniMode else { return }
        // 先启动窗口 frame 动画，再切换内容状态：让面板立即开始移动，降低点击后的感知延迟
        windowManager?.collapse { [weak self] in
            Task { await self?.persistMiniModeState() }
        }
        isMiniMode = true
    }

    func expand() {
        guard isMiniMode else { return }
        windowManager?.expand { [weak self] in
            Task { await self?.persistMiniModeState() }
        }
        isMiniMode = false
    }

    func toggleMiniMode() {
        isMiniMode ? expand() : collapse()
    }

    func persistMiniModeState() async {
        do {
            let normalFrame = windowManager?.currentFrameForPersistence()
            let state = MiniModeState(
                isMiniMode: isMiniMode,
                activeTab: miniActiveTab,
                normalFrame: normalFrame
            )
            try await repository.saveMiniModeState(state)
        } catch {
            // 窗口状态持久化失败不影响主流程；下次启动回退到默认形态。
        }
    }

    func bootstrap() async {
        if let language = try? await repository.loadAppLanguage() {
            languageStore.apply(language)
        }
        do {
            let snapshot = try await onboardingViewModel.loadSnapshot()
            todoListViewModel.configure(choiceField: snapshot.choiceField)
            if snapshot.hasToken, snapshot.tasksDatabaseID != nil, snapshot.journalDatabaseID != nil {
                screen = .widget
                await refreshWorkspace()
            } else {
                screen = .welcome
            }
        } catch {
            screen = .welcome
            bannerMessageKey = nil
            bannerMessage = AppMessage(.startupFailed, arguments: [error.localizedDescription])
        }
    }

    func refreshWorkspace() async {
        screen = .widget
        if let snapshot = try? await onboardingViewModel.loadSnapshot() {
            todoListViewModel.configure(choiceField: snapshot.choiceField)
        }
        await todoListViewModel.load()
        await journalViewModel.load()
        if todoListViewModel.errorMessage == nil, journalViewModel.errorMessage == nil {
            bannerMessage = AppMessage(.workspaceSynced)
            bannerMessageKey = nil
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                self?.bannerMessage = nil
            }
        } else if let message = todoListViewModel.errorMessage ?? journalViewModel.errorMessage {
            bannerMessageKey = nil
            bannerMessage = message
        }
    }

    func openSettings() {
        if isMiniMode { expand() }
        if screen != .settings {
            screenBeforeSettings = screen
        }
        screen = .settings
        Task { @MainActor [weak self] in
            do {
                let snapshot = try await self?.onboardingViewModel.loadSnapshot()
                if let snapshot {
                    self?.todoListViewModel.configure(choiceField: snapshot.choiceField)
                }
            } catch {
                self?.onboardingViewModel.statusMessageKey = nil
                self?.onboardingViewModel.statusMessage = AppMessage(.settingsLoadFailed, arguments: [error.localizedDescription])
                self?.onboardingViewModel.isErrorState = true
            }
        }
    }

    func selectLanguage(_ language: AppLanguage) {
        guard languageStore.language != language else { return }
        let previousLanguage = languageStore.language
        languageStore.apply(language)

        Task { @MainActor [weak self] in
            do {
                try await self?.repository.saveAppLanguage(language)
            } catch {
                self?.languageStore.apply(previousLanguage)
                self?.onboardingViewModel.statusMessageKey = nil
                self?.onboardingViewModel.statusMessage = AppMessage(.savingLanguageFailed)
                self?.onboardingViewModel.isErrorState = true
            }
        }
    }

    func resetConfigurationFromSettings() async {
        do {
            try await onboardingViewModel.resetConfigurationForRestart()
            screenBeforeSettings = .welcome
            bannerMessage = nil
            bannerMessageKey = nil
            screen = .welcome
        } catch {
            onboardingViewModel.statusMessageKey = nil
            onboardingViewModel.statusMessage = AppMessage(.resetConfigurationFailed)
            onboardingViewModel.isErrorState = true
        }
    }

    func returnFromSettings() {
        screen = screenBeforeSettings
    }
}

struct OnboardingView: View {
    enum Mode {
        case onboarding
        case settings
    }

    private enum DatabaseHelpTopic: String, Identifiable {
        case tasks
        case journal

        var id: String { rawValue }
    }

    @ObservedObject var viewModel: OnboardingViewModel
    let mode: Mode
    var onBack: (() -> Void)?
    var onResetConfiguration: (() async -> Void)?
    var onLanguageChange: ((AppLanguage) -> Void)?
    @EnvironmentObject private var languageStore: LanguageStore
    @State private var isShowingTokenHelp = false
    @State private var activeDatabaseHelpTopic: DatabaseHelpTopic?
    @State private var showingResetConfirmation = false
    @State private var isResetActionPending = false
    @State private var isAppeared = false
    @State private var isPrimaryButtonHovered = false

    private var isOnboardingMode: Bool {
        mode == .onboarding
    }

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                modalHeader

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: OnboardingModalMetrics.onboardingContentSpacing) {
                        if mode == .settings {
                            settingsIntro
                            languageSection
                        } else {
                            onboardingHero
                            languageSection
                        }

                        tokenSection
                        databaseSection(
                            title: languageStore.text(mode == .settings ? .tasksDatabaseID : .tasksDatabase),
                            placeholder: languageStore.text(mode == .settings ? .tasksDatabasePrompt : .pasteFullURL),
                            text: $viewModel.tasksDatabaseInput,
                            normalize: viewModel.normalizeTasksDatabaseInput,
                            helpAccessibilityLabel: languageStore.text(.howToGet),
                            helpAction: {
                                activeDatabaseHelpTopic = .tasks
                            }
                        )
                        databaseSection(
                            title: languageStore.text(mode == .settings ? .journalDatabaseID : .journalDatabase),
                            placeholder: languageStore.text(mode == .settings ? .journalDatabasePrompt : .pasteFullURL),
                            text: $viewModel.journalDatabaseInput,
                            normalize: viewModel.normalizeJournalDatabaseInput,
                            helpAccessibilityLabel: languageStore.text(.howToGet),
                            helpAction: {
                                activeDatabaseHelpTopic = .journal
                            }
                        )

                        if let messageKey = viewModel.statusMessageKey {
                            statusBanner(message: languageStore.text(messageKey))
                        } else if let message = viewModel.statusMessage {
                            statusBanner(message: languageStore.text(message))
                        }

                        if mode == .settings {
                            resetSection
                        }

                        primaryButton
                    }
                    .padding(.horizontal, OnboardingModalMetrics.onboardingHorizontalPadding)
                    .padding(.top, OnboardingModalMetrics.onboardingTopPadding)
                    .padding(.bottom, OnboardingModalMetrics.onboardingBottomPadding)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: OnboardingModalMetrics.cardCornerRadius, style: .continuous)
                    .fill(OnboardingModalPalette.modalBackground)
                    .shadow(
                        color: OnboardingModalPalette.cardShadow,
                        radius: 24,
                        x: 0,
                        y: 12
                    )
            )
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .opacity(isAppeared ? 1 : 0)
            .offset(y: isAppeared ? 0 : 10)
            .animation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.32), value: isAppeared)
        }
        .sheet(isPresented: $isShowingTokenHelp) {
            NotionTokenHelpView()
        }
        .sheet(item: $activeDatabaseHelpTopic) { topic in
            switch topic {
            case .tasks:
                TasksDatabaseHelpView()
            case .journal:
                JournalDatabaseHelpView()
            }
        }
        .confirmationDialog(
            languageStore.text(.resetConfiguration),
            isPresented: $showingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button(languageStore.text(.resetConfiguration), role: .destructive) {
                guard !(viewModel.isWorking || isResetActionPending) else { return }
                isResetActionPending = true
                Task {
                    await onResetConfiguration?()
                    await MainActor.run {
                        isResetActionPending = false
                    }
                }
            }
            Button(languageStore.text(.cancel), role: .cancel) {}
        } message: {
            Text(languageStore.text(.resetConfigurationConfirmation))
        }
        .onAppear {
            guard !isAppeared else { return }
            isAppeared = true
        }
    }

    private var modalHeader: some View {
        ZStack {
            if mode == .settings {
                Text(languageStore.text(.settingsTitle))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(OnboardingModalPalette.primaryText)
            }

            HStack {
                if let onBack {
                    Button {
                        onBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(OnboardingModalPalette.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .disabled(mode == .settings && (viewModel.isWorking || isResetActionPending))
                } else {
                    headerBalancePlaceholder
                }

                Spacer()
                if mode == .onboarding {
                    Text(languageStore.text(.initialConfiguration))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(OnboardingModalPalette.primaryText)
                        .frame(maxWidth: .infinity)
                }
                Spacer()
                headerBalancePlaceholder
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(OnboardingModalPalette.border)
                .frame(height: 1)
        }
    }

    private var headerBalancePlaceholder: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(OnboardingModalPalette.placeholderDecoration)
                .frame(width: 4, height: 4)
            Circle()
                .fill(OnboardingModalPalette.placeholderDecoration.opacity(0.7))
                .frame(width: 4, height: 4)
            Circle()
                .fill(OnboardingModalPalette.placeholderDecoration.opacity(0.45))
                .frame(width: 4, height: 4)
        }
        .frame(width: 32, height: 32)
        .accessibilityHidden(true)
    }

    private var onboardingHero: some View {
        HStack(alignment: .top, spacing: OnboardingModalMetrics.onboardingHeroSpacing) {
            Image("ConnectModalHero")
                .resizable()
                .scaledToFit()
                .frame(
                    width: OnboardingModalMetrics.onboardingHeroIllustrationSize,
                    height: OnboardingModalMetrics.onboardingHeroIllustrationSize
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: OnboardingModalMetrics.onboardingHeroTextSpacing) {
                Text(languageStore.text(.connectNotion))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(OnboardingModalPalette.primaryText)
                Text(languageStore.text(.connectNotionSubtitle))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(OnboardingModalPalette.secondaryText)
                    .lineSpacing(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var settingsIntro: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                Text(languageStore.text(.onboardingDescription))
                    .font(.system(size: 14))
                    .foregroundStyle(OnboardingModalPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            settingsDecorationCluster
        }
        .padding(.bottom, 4)
    }

    private var languageSection: some View {
        HStack {
            Label("Language", systemImage: "globe")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(OnboardingModalPalette.primaryText)

            Spacer()

            Menu {
                ForEach(AppLanguage.allCases, id: \.self) { language in
                    Button {
                        onLanguageChange?(language)
                    } label: {
                        Text(language.displayName)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(languageStore.language.displayName)
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(OnboardingModalPalette.secondaryText)
            }
            .menuStyle(.borderlessButton)
            .disabled(viewModel.isWorking || isResetActionPending)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(OnboardingModalPalette.inputBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(OnboardingModalPalette.inputBorder, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }

    private var tokenSection: some View {
        VStack(alignment: .leading, spacing: OnboardingModalMetrics.onboardingSectionSpacing) {
            HStack(alignment: .firstTextBaseline) {
                Text(languageStore.text(.notionToken))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(OnboardingModalPalette.primaryText)
                Spacer()
                Button {
                    isShowingTokenHelp = true
                } label: {
                    HStack(spacing: 4) {
                        Text(languageStore.text(.howToGet))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(OnboardingModalPalette.secondaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(languageStore.text(.howToGet))
            }

            inputShell(icon: "lock") {
                SecureField("", text: $viewModel.token, prompt: Text(languageStore.text(.tokenPrompt)).foregroundColor(OnboardingModalPalette.placeholderText))
                    .textFieldStyle(.plain)
                    .disabled(viewModel.isWorking)
                    .accessibilityLabel(languageStore.text(.notionToken))
            }

            HStack(alignment: .center, spacing: 6) {
                Image(systemName: "lock")
                    .font(.system(size: 10, weight: .medium))
                Text(languageStore.text(mode == .settings ? .tokenStoredSettings : .tokenStoredOnboarding))
                    .font(.system(size: 12))
            }
            .foregroundStyle(OnboardingModalPalette.secondaryText)
        }
    }

    private func databaseSection(
        title: String,
        placeholder: String,
        text: Binding<String>,
        normalize: @escaping () -> Void,
        helpAccessibilityLabel: String? = nil,
        helpAction: (() -> Void)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: OnboardingModalMetrics.onboardingSectionSpacing) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(OnboardingModalPalette.primaryText)
                Spacer()
                Text(languageStore.text(.pasteFullURL))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(OnboardingModalPalette.secondaryText)
            }

            HStack(alignment: .center, spacing: 8) {
                inputShell(icon: "doc.text") {
                    TextField("", text: text, prompt: Text(placeholder).foregroundColor(OnboardingModalPalette.placeholderText))
                        .textFieldStyle(.plain)
                        .disabled(viewModel.isWorking)
                        .accessibilityLabel(title)
                        .onChange(of: text.wrappedValue) {
                            normalize()
                        }
                }
                .frame(maxWidth: .infinity)

                if let helpAction {
                    Button(action: helpAction) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 18, height: 18)
                            .foregroundStyle(OnboardingModalPalette.secondaryText)
                    }
                    .buttonStyle(DatabaseHelpButtonStyle())
                    .disabled(viewModel.isWorking)
                    .accessibilityLabel(helpAccessibilityLabel ?? languageStore.text(.howToGet))
                }
            }
        }
    }

    private var settingsDecorationCluster: some View {
        ZStack {
            VStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in
                    HStack(spacing: 4) {
                        ForEach(0..<5, id: \.self) { _ in
                            Circle()
                                .fill(OnboardingModalPalette.decoDot)
                                .frame(width: 3, height: 3)
                        }
                    }
                }
            }
            .offset(x: -8, y: -2)

            Image(systemName: "sparkle")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(OnboardingModalPalette.decoAccent)
                .offset(x: 26, y: 8)

            SettingsCurveShape()
                .stroke(OnboardingModalPalette.decoAccent.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .frame(width: 26, height: 18)
                .offset(x: 18, y: 28)
        }
        .frame(width: 72, height: 54)
        .accessibilityHidden(true)
    }

    private func inputShell<Field: View>(icon: String, @ViewBuilder field: () -> Field) -> some View {
        HStack(spacing: OnboardingModalMetrics.onboardingInputIconSpacing) {
            Image(systemName: icon)
                .font(.system(size: OnboardingModalMetrics.onboardingInputIconSize, weight: .medium))
                .foregroundStyle(OnboardingModalPalette.tertiaryText)
                .frame(width: OnboardingModalMetrics.onboardingInputIconWidth)

            field()
                .font(.system(size: 13))
                .foregroundStyle(OnboardingModalPalette.primaryText)
        }
        .padding(.horizontal, OnboardingModalMetrics.onboardingInputHorizontalPadding)
        .padding(.vertical, OnboardingModalMetrics.onboardingInputVerticalPadding)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(OnboardingModalPalette.inputBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(OnboardingModalPalette.inputBorder, lineWidth: 1)
        )
    }

    private func statusBanner(message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: viewModel.isErrorState ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
            Text(message)
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(viewModel.isErrorState ? OnboardingModalPalette.errorText : OnboardingModalPalette.successText)
        .padding(.horizontal, OnboardingModalMetrics.onboardingStatusHorizontalPadding)
        .padding(.vertical, OnboardingModalMetrics.onboardingStatusVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(viewModel.isErrorState ? OnboardingModalPalette.errorBackground : OnboardingModalPalette.successBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(viewModel.isErrorState ? OnboardingModalPalette.errorBorder : OnboardingModalPalette.successBorder, lineWidth: 1)
        )
    }

    private var resetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(languageStore.text(.resetConfiguration))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(OnboardingModalPalette.errorText)

            Text(languageStore.text(.resetConfigurationDescription))
                .font(.system(size: 12))
                .foregroundStyle(OnboardingModalPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                showingResetConfirmation = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 12, weight: .semibold))
                    Text(languageStore.text(.resetConfiguration))
                        .font(.system(size: 13, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 42)
            }
            .buttonStyle(DestructiveSecondaryButtonStyle())
            .disabled(viewModel.isWorking || isResetActionPending)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(OnboardingModalPalette.errorBackground.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(OnboardingModalPalette.errorBorder, lineWidth: 1)
        )
    }

    private var primaryButton: some View {
        Button {
            Task {
                await viewModel.validateAndSave()
            }
        } label: {
            HStack(spacing: OnboardingModalMetrics.onboardingButtonSpacing) {
                if viewModel.isWorking {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    notionMark
                }

                Text(languageStore.text(mode == .settings ? .saveSettings : .verifyAndContinue))
                    .font(.system(size: 13, weight: .semibold))

                if !viewModel.isWorking {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                        .offset(x: isPrimaryButtonHovered ? OnboardingModalMetrics.onboardingButtonHoverOffset : 0)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: OnboardingModalMetrics.onboardingButtonHeight)
        }
        .buttonStyle(OnboardingPrimaryButtonStyle(isHovered: isPrimaryButtonHovered))
        .onHover { isHovering in
            isPrimaryButtonHovered = isHovering
        }
        .disabled(viewModel.isWorking)
    }

    private var notionMark: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                .fill(Color.white)
                .frame(width: 16, height: 16)
            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                .stroke(Color.black.opacity(0.18), lineWidth: 0.8)
                .frame(width: 16, height: 16)
            Text("N")
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(Color.black)
        }
        .accessibilityHidden(true)
    }
}

private enum OnboardingModalMetrics {
    static let onboardingHorizontalPadding: CGFloat = 16
    static let onboardingTopPadding: CGFloat = 20
    static let onboardingBottomPadding: CGFloat = 20
    static let onboardingContentSpacing: CGFloat = 18
    static let onboardingHeroSpacing: CGFloat = 14
    static let onboardingHeroIllustrationSize: CGFloat = 68
    static let onboardingHeroTextSpacing: CGFloat = 6
    static let onboardingSectionSpacing: CGFloat = 8
    static let onboardingInputHorizontalPadding: CGFloat = 12
    static let onboardingInputVerticalPadding: CGFloat = 10
    static let onboardingInputIconSpacing: CGFloat = 8
    static let onboardingInputIconSize: CGFloat = 13
    static let onboardingInputIconWidth: CGFloat = 14
    static let onboardingStatusHorizontalPadding: CGFloat = 12
    static let onboardingStatusVerticalPadding: CGFloat = 10
    static let onboardingButtonHeight: CGFloat = 44
    static let onboardingButtonSpacing: CGFloat = 8
    static let onboardingButtonHoverOffset: CGFloat = 2
    static let cardCornerRadius: CGFloat = 18
}

private enum OnboardingModalPalette {
    static let modalBackground = Color.white
    static let cardShadow = Color.black.opacity(0.08)
    static let inputBackground = Color(red: 0.976, green: 0.976, blue: 0.976)
    static let inputBorder = Color(red: 0.91, green: 0.91, blue: 0.91)
    static let border = Color(red: 0.91, green: 0.91, blue: 0.91)
    static let primaryText = Color(red: 0.102, green: 0.102, blue: 0.102)
    static let secondaryText = Color(red: 0.42, green: 0.42, blue: 0.42)
    static let tertiaryText = Color(red: 0.612, green: 0.639, blue: 0.686)
    static let placeholderText = Color(red: 0.75, green: 0.75, blue: 0.75)
    static let placeholderDecoration = Color(red: 0.84, green: 0.84, blue: 0.84)
    static let buttonFill = Color(red: 0.176, green: 0.176, blue: 0.176)
    static let buttonPressed = Color(red: 0.239, green: 0.239, blue: 0.239)
    static let buttonShadow = Color.black.opacity(0.18)
    static let buttonHoverShadow = Color.black.opacity(0.24)
    static let successText = Color(red: 0.298, green: 0.686, blue: 0.314)
    static let successBackground = Color(red: 0.953, green: 0.985, blue: 0.953)
    static let successBorder = Color(red: 0.808, green: 0.925, blue: 0.812)
    static let errorText = Color(red: 0.76, green: 0.208, blue: 0.208)
    static let errorBackground = Color(red: 0.996, green: 0.949, blue: 0.949)
    static let errorBorder = Color(red: 0.945, green: 0.792, blue: 0.792)
    static let decoDot = Color(red: 0.65, green: 0.65, blue: 0.65).opacity(0.28)
    static let decoAccent = Color(red: 0.72, green: 0.72, blue: 0.72)
}

private struct OnboardingPrimaryButtonStyle: ButtonStyle {
    let isHovered: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(configuration.isPressed ? OnboardingModalPalette.buttonPressed : OnboardingModalPalette.buttonFill)
            )
            .shadow(
                color: isHovered ? OnboardingModalPalette.buttonHoverShadow : OnboardingModalPalette.buttonShadow,
                radius: configuration.isPressed ? 6 : (isHovered ? 16 : 12),
                y: configuration.isPressed ? 4 : (isHovered ? 10 : 8)
            )
            .offset(y: isHovered && !configuration.isPressed ? -1 : 0)
            .scaleEffect(configuration.isPressed ? 0.995 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.16), value: isHovered)
    }
}

private struct DestructiveSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foregroundColor(for: configuration))
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(backgroundColor(for: configuration))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .opacity(isEnabled ? 1 : 0.72)
            .scaleEffect(configuration.isPressed && isEnabled ? 0.992 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.12), value: isEnabled)
    }

    private func foregroundColor(for configuration: Configuration) -> Color {
        guard isEnabled else {
            return OnboardingModalPalette.errorText.opacity(0.45)
        }
        return configuration.isPressed ? Color.white.opacity(0.95) : OnboardingModalPalette.errorText
    }

    private func backgroundColor(for configuration: Configuration) -> Color {
        guard isEnabled else {
            return OnboardingModalPalette.errorBackground.opacity(0.42)
        }
        return configuration.isPressed ? OnboardingModalPalette.errorText : Color.white.opacity(0.9)
    }

    private var borderColor: Color {
        guard isEnabled else {
            return OnboardingModalPalette.errorBorder.opacity(0.45)
        }
        return OnboardingModalPalette.errorBorder
    }
}

private struct SettingsCurveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.midX * 0.9, y: rect.midY)
        )
        return path
    }
}

private struct NotionTokenHelpView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageStore: LanguageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(languageStore.text(.notionTokenHelpTitle))
                    .font(.title3.weight(.semibold))
                Spacer()
                Button(languageStore.text(.close)) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(languageStore.text(.tokenHelpStep1))
                Text(languageStore.text(.tokenHelpStep2))
                Text(languageStore.text(.tokenHelpStep3))
                Text(languageStore.text(.tokenHelpStep4))
            }
            .font(.callout)
            .foregroundStyle(.secondary)

            Link(languageStore.text(.openNotionIntegrations), destination: URL(string: "https://www.notion.so/my-integrations")!)

            Spacer()
        }
        .padding(24)
        .frame(width: 420, height: 260)
    }
}

private struct TasksDatabaseHelpView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageStore: LanguageStore

    var body: some View {
        HelpSheetLayout(titleKey: .tasksDatabaseHelpTitle, onClose: { dismiss() }) {
            Group {
                Text(languageStore.text(.tasksHelpStep1))
                Text(languageStore.text(.tasksHelpStep2))
                Text(languageStore.text(.tasksHelpStep3))
                Text(languageStore.text(.tasksHelpStep4))
                Text(languageStore.text(.tasksHelpStep5))
                Text(languageStore.text(.tasksHelpStep6))
            }
        }
    }
}

private struct JournalDatabaseHelpView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageStore: LanguageStore

    var body: some View {
        HelpSheetLayout(titleKey: .journalDatabaseHelpTitle, onClose: { dismiss() }) {
            Group {
                Text(languageStore.text(.journalHelpStep1))
                Text(languageStore.text(.journalHelpStep2))
                Text(languageStore.text(.journalHelpStep3))
                Text(languageStore.text(.journalHelpStep4))
                Text(languageStore.text(.journalHelpStep5))
                Text(languageStore.text(.journalHelpStep6))
                Text(languageStore.text(.journalHelpStep7))
            }
        }
    }
}

private struct HelpSheetLayout<Content: View>: View {
    @EnvironmentObject private var languageStore: LanguageStore
    let titleKey: AppText.Key
    let onClose: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(languageStore.text(titleKey))
                    .font(.title3.weight(.semibold))
                Spacer()
                Button(languageStore.text(.close)) {
                    onClose()
                }
                .keyboardShortcut(.cancelAction)
            }

            ScrollView(showsIndicators: true) {
                VStack(alignment: .leading, spacing: 10) {
                    content
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            }

            Link(languageStore.text(.openNotion), destination: URL(string: "https://www.notion.so")!)
        }
        .padding(24)
        .frame(width: 460)
        .frame(minHeight: 320, idealHeight: 360)
    }
}

private struct DatabaseHelpButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 38, height: 38)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isEnabled ? OnboardingModalPalette.inputBackground : OnboardingModalPalette.inputBackground.opacity(0.72))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(OnboardingModalPalette.inputBorder, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private enum FloatingWidgetPalette {
    static let shellBackground = Color.white
    static let tabPillBg = Color(red: 0.984, green: 0.976, blue: 0.965).opacity(0.94)
    static let tabPillBorder = Color(red: 0.89, green: 0.87, blue: 0.85).opacity(0.92)
    static let tabPillShadow = Color(red: 0.631, green: 0.569, blue: 0.506).opacity(0.1)
    static let tabText = Color(red: 0.137, green: 0.137, blue: 0.137)
    static let activeTabTop = Color(red: 0.945, green: 0.937, blue: 0.925)
    static let activeTabBottom = Color(red: 0.925, green: 0.91, blue: 0.894)
    static let activeTabShadow = Color(red: 0.702, green: 0.647, blue: 0.592).opacity(0.16)
    static let todoToolbarText = Color(red: 0.129, green: 0.125, blue: 0.122)
    static let syncBannerBg = Color(red: 0.965, green: 0.953, blue: 0.937).opacity(0.96)
    static let syncBannerText = Color(red: 0.49, green: 0.47, blue: 0.447)
    static let taskTitle = Color(red: 0.137, green: 0.133, blue: 0.129)
    static let taskTitleCompleted = Color(red: 0.533, green: 0.533, blue: 0.533)
    static let checkboxBorder = Color(red: 0.741, green: 0.714, blue: 0.686)
    static let checkboxCompleteTop = Color(red: 0.49, green: 0.835, blue: 0.427)
    static let checkboxCompleteBottom = Color(red: 0.4, green: 0.78, blue: 0.373)
    static let metaText = Color(red: 0.545, green: 0.522, blue: 0.494)
    static let dangerText = Color(red: 1.0, green: 0.294, blue: 0.243)
    static let warningText = Color(red: 1.0, green: 0.616, blue: 0.184)
    static let durationText = Color(red: 0.78, green: 0.45, blue: 0.14)
    static let durationBg = Color(red: 0.996, green: 0.949, blue: 0.886)
    static let retryText = Color(red: 0.4, green: 0.376, blue: 0.353)
    static let dividerColor = Color(red: 0.914, green: 0.894, blue: 0.875).opacity(0.95)
    static let journalDate = Color(red: 0.604, green: 0.576, blue: 0.553)
    static let editorBg = Color(red: 0.992, green: 0.988, blue: 0.98).opacity(0.96)
    static let editorBorder = Color(red: 0.882, green: 0.863, blue: 0.839).opacity(0.96)
    static let editorText = Color(red: 0.149, green: 0.145, blue: 0.141)
    static let statusText = Color(red: 0.655, green: 0.627, blue: 0.604)
    static let actionBtnColor = Color(red: 0.47, green: 0.459, blue: 0.447)
    static let actionBtnHoverBg = Color(red: 0.949, green: 0.933, blue: 0.914).opacity(0.92)
    static let actionBtnActiveBg = Color(red: 0.922, green: 0.902, blue: 0.878).opacity(0.96)
    static let moreBtnBg = Color(red: 0.996, green: 0.992, blue: 0.984).opacity(0.96)
    static let moreBtnBorder = Color(red: 0.918, green: 0.898, blue: 0.878).opacity(0.95)
    static let scrollbarThumb = Color(red: 0.941, green: 0.925, blue: 0.91).opacity(0.98)
    static let actionBtnHoverColor = Color(red: 0.333, green: 0.322, blue: 0.31)
    static let expandHintBg = Color(red: 0.176, green: 0.176, blue: 0.176).opacity(0.88)
    static let editorInset = Color(red: 0.965, green: 0.953, blue: 0.941).opacity(0.88)
    static let todoDateTitle = Color(red: 0.129, green: 0.125, blue: 0.122)
    static let checkBg = Color.white.opacity(0.92)
}

private enum FloatingWidgetMetrics {
    static let shellPadding = EdgeInsets(top: 12, leading: 16, bottom: 16, trailing: 16)
    static let topBarBottomSpacing: CGFloat = 18

    static let todoToolbarBottomSpacing: CGFloat = 18
    static let todoDateTitleFontSize: CGFloat = 14
    static let todoDateTitleWidth: CGFloat = 60
    static let todoDateNavigationSpacing: CGFloat = 4
    static let jumpToTodayWidth: CGFloat = 44
    static let jumpToTodayLeadingPadding: CGFloat = 2
    static let headerIconButtonSpacing: CGFloat = 12
    static let headerIconButtonSize: CGFloat = 24
    static let headerIconSymbolSize: CGFloat = 16
    static let syncBannerBottomSpacing: CGFloat = 14

    static let taskRowHorizontalSpacing: CGFloat = 10
    static let taskRowTextStackSpacing: CGFloat = 6
    static let taskRowMetaSpacing: CGFloat = 4
    static let taskRowActionSpacing: CGFloat = 6
    static let taskRowTopPadding: CGFloat = 14
    static let taskRowBottomPadding: CGFloat = 16
    static let todoListContentInsets = EdgeInsets(top: 14, leading: 14, bottom: 36, trailing: 16)

    static let journalDateBottomSpacing: CGFloat = 14
    static let journalEditorFontSize: CGFloat = 13
    static let journalEditorLineSpacing: CGFloat = 6
    static let journalEditorInsets = EdgeInsets(top: 16, leading: 16, bottom: 40, trailing: 18)
    static let journalStatusSpacing: CGFloat = 4
    static let journalStatusTopSpacing: CGFloat = 10

    static let panelCornerRadius: CGFloat = 12
    static let panelBorderLineWidth: CGFloat = 0.5
}

struct FloatingWidgetView: View {
    private enum WidgetTab: CaseIterable {
        case todo
        case journal

        var textKey: AppText.Key {
            switch self {
            case .todo:
                return .todoTab
            case .journal:
                return .journalTab
            }
        }
    }

    @EnvironmentObject private var languageStore: LanguageStore
    @State private var selectedTab: WidgetTab
    @ObservedObject var todoViewModel: TodoListViewModel
    @ObservedObject var journalViewModel: JournalViewModel
    @ObservedObject private var newTaskViewModel: NewTaskViewModel
    @State private var taskPendingDeletion: TaskItem?
    let refreshAction: @MainActor () async -> Void
    var bannerMessage: AppMessage?
    var bannerMessageKey: AppText.Key?
    let initialActiveTab: MiniActiveTab
    let onActiveTabChange: ((MiniActiveTab) -> Void)?
    let onCollapse: (() -> Void)?

    init(
        todoViewModel: TodoListViewModel,
        journalViewModel: JournalViewModel,
        refreshAction: @escaping @MainActor () async -> Void,
        bannerMessage: AppMessage?,
        bannerMessageKey: AppText.Key?,
        activeTab: MiniActiveTab = .todo,
        onActiveTabChange: ((MiniActiveTab) -> Void)? = nil,
        onCollapse: (() -> Void)? = nil
    ) {
        self.todoViewModel = todoViewModel
        self.journalViewModel = journalViewModel
        _newTaskViewModel = ObservedObject(wrappedValue: todoViewModel.newTaskViewModel)
        self.initialActiveTab = activeTab
        _selectedTab = State(initialValue: FloatingWidgetView.widgetTab(from: activeTab))
        self.refreshAction = refreshAction
        self.bannerMessage = bannerMessage
        self.bannerMessageKey = bannerMessageKey
        self.onActiveTabChange = onActiveTabChange
        self.onCollapse = onCollapse
    }

    private static func widgetTab(from miniTab: MiniActiveTab) -> WidgetTab {
        switch miniTab {
        case .todo:
            return .todo
        case .journal:
            return .journal
        }
    }

    private func miniActiveTab(from widgetTab: WidgetTab) -> MiniActiveTab {
        switch widgetTab {
        case .todo:
            return .todo
        case .journal:
            return .journal
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.bottom, FloatingWidgetMetrics.topBarBottomSpacing)

            Group {
                if selectedTab == .todo {
                    todoPanel
                } else {
                    journalPanel
                }
            }
        }
        .padding(FloatingWidgetMetrics.shellPadding)
        .background(FloatingWidgetPalette.shellBackground)
    }

    private var topBar: some View {
        ZStack {
            HStack(spacing: 0) {
                ForEach(WidgetTab.allCases, id: \.self) { tab in
                    tabButton(tab)
                }
            }
            .padding(3)
            .background(
                Capsule(style: .continuous)
                    .fill(FloatingWidgetPalette.tabPillBg)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(FloatingWidgetPalette.tabPillBorder, lineWidth: 1)
            )
            .shadow(color: FloatingWidgetPalette.tabPillShadow, radius: 6, y: 0)

            HStack {
                Color.clear
                    .frame(width: 26, height: 26)
                    .accessibilityHidden(true)

                Spacer()

                Button {
                    onCollapse?()
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(FloatingWidgetActionButtonStyle())

                Button {
                    NSApp.keyWindow?.orderOut(nil)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(FloatingWidgetActionButtonStyle())
            }
        }
    }

    private func tabButton(_ tab: WidgetTab) -> some View {
        let isActive = selectedTab == tab
        return Button {
            withAnimation(.easeOut(duration: 0.22)) {
                selectedTab = tab
                onActiveTabChange?(miniActiveTab(from: tab))
            }
        } label: {
            Text(languageStore.text(tab.textKey))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(FloatingWidgetPalette.tabText)
                .modifier(TrackingModifier(value: -0.13))
                .frame(minWidth: 64)
                .frame(height: 32)
                .contentShape(Rectangle())
                .background(
                    Group {
                        if isActive {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(LinearGradient(
                                    colors: [FloatingWidgetPalette.activeTabTop, FloatingWidgetPalette.activeTabBottom],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ))
                                .shadow(color: FloatingWidgetPalette.activeTabShadow, radius: 4, y: 2)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }

    private var todoPanel: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                todoToolbar
                    .padding(.bottom, FloatingWidgetMetrics.todoToolbarBottomSpacing)

                syncBanner
                    .padding(.bottom, FloatingWidgetMetrics.syncBannerBottomSpacing)

                PomodoroFocusCard(viewModel: todoViewModel)

                if todoViewModel.isLoading {
                    ProgressView(languageStore.text(.loadingTasks))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if todoViewModel.tasks.isEmpty && todoViewModel.pendingTask == nil {
                    emptyTasksView
                } else {
                    taskListView
                }

                if let message = todoViewModel.errorMessage {
                    Text(languageStore.text(message))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(FloatingWidgetPalette.dangerText)
                        .padding(.top, 8)
                }
            }

            if newTaskViewModel.showForm {
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        newTaskViewModel.dismissForm()
                    }
                NewTaskFormCard(viewModel: newTaskViewModel)
            }

            if todoViewModel.editingTask != nil {
                EditTaskFormCard(viewModel: todoViewModel)
            }

            if todoViewModel.pomodoroStartTask != nil {
                PomodoroStartCard(viewModel: todoViewModel)
            }

            if todoViewModel.pomodoroPrompt != nil {
                PomodoroPromptCard(viewModel: todoViewModel)
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    ToastHostView(toast: todoViewModel.toast)
                }
                .padding(.trailing, 8)
                .padding(.bottom, 8)
            }
        }
        .confirmationDialog(
            languageStore.text(.deleteTaskConfirmation),
            isPresented: Binding(
                get: { taskPendingDeletion != nil },
                set: { isPresented in
                    if !isPresented {
                        taskPendingDeletion = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            if let taskPendingDeletion {
                Button(languageStore.text(.deleteTask), role: .destructive) {
                    let taskToDelete = taskPendingDeletion
                    self.taskPendingDeletion = nil
                    Task {
                        await todoViewModel.deleteTask(taskToDelete)
                    }
                }
            }
        } message: {
            Text(languageStore.text(.deleteTaskArchiveMessage))
        }
    }

    private var todoToolbar: some View {
        HStack(spacing: 0) {
            HStack(spacing: FloatingWidgetMetrics.todoDateNavigationSpacing) {
                Button {
                    Task { await todoViewModel.showPreviousDay() }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(FloatingWidgetNavButtonStyle())

                Text(todoTitle)
                    .font(.system(size: FloatingWidgetMetrics.todoDateTitleFontSize, weight: .bold))
                    .foregroundStyle(FloatingWidgetPalette.todoDateTitle)
                    .modifier(TrackingModifier(value: -0.28))
                    .lineLimit(1)
                    .allowsTightening(true)
                    .frame(width: FloatingWidgetMetrics.todoDateTitleWidth, alignment: .center)

                Button {
                    Task { await todoViewModel.showNextDay() }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(FloatingWidgetNavButtonStyle())
            }

            if !todoViewModel.isShowingToday {
                Button(languageStore.text(.backToToday)) {
                    Task { await todoViewModel.jumpToToday() }
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(FloatingWidgetPalette.metaText)
                .padding(.leading, FloatingWidgetMetrics.jumpToTodayLeadingPadding)
                .frame(width: FloatingWidgetMetrics.jumpToTodayWidth, alignment: .trailing)
            } else {
                Spacer(minLength: 0)
                    .frame(width: FloatingWidgetMetrics.jumpToTodayWidth)
            }

            Spacer()

            HStack(spacing: FloatingWidgetMetrics.headerIconButtonSpacing) {
                Button {
                    todoViewModel.openNewTaskForm()
                } label: {
                    headerActionIcon(systemName: "plus")
                }
                .buttonStyle(FloatingWidgetIconButtonStyle())

                Button {
                    Task { await refreshAction() }
                } label: {
                    headerActionIcon(systemName: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(FloatingWidgetIconButtonStyle())

                if todoViewModel.tasksDatabaseURL != nil {
                    Button {
                        todoViewModel.openTasksDatabaseInNotion()
                    } label: {
                        headerActionIcon(systemName: "arrow.up.forward.square")
                    }
                    .buttonStyle(FloatingWidgetIconButtonStyle())
                }
            }
        }
    }

    private var syncBanner: some View {
        Group {
            if let banner = localizedBannerMessage {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.2.circlepath")
                        .font(.system(size: 12, weight: .medium))
                        .opacity(0.7)
                    Text(banner)
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(FloatingWidgetPalette.syncBannerText)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(
                    Capsule(style: .continuous)
                        .fill(FloatingWidgetPalette.syncBannerBg)
                )
            }
        }
    }

    private var taskListView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                if let pending = todoViewModel.pendingTask {
                    PendingTodoRowView(item: pending, showFailure: todoViewModel.showFailureHighlight)
                        .padding(.top, FloatingWidgetMetrics.taskRowTopPadding)
                        .padding(.bottom, FloatingWidgetMetrics.taskRowBottomPadding)
                    Rectangle()
                        .fill(FloatingWidgetPalette.dividerColor)
                        .frame(height: 1)
                }

                ForEach(todoViewModel.tasks) { task in
                    taskRowView(task)
                    if task.id != todoViewModel.tasks.last?.id {
                        Rectangle()
                            .fill(FloatingWidgetPalette.dividerColor)
                            .frame(height: 1)
                    }
                }
            }
            .padding(FloatingWidgetMetrics.todoListContentInsets)
        }
        .background(
            RoundedRectangle(cornerRadius: FloatingWidgetMetrics.panelCornerRadius, style: .continuous)
                .fill(FloatingWidgetPalette.editorBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: FloatingWidgetMetrics.panelCornerRadius, style: .continuous)
                .stroke(FloatingWidgetPalette.editorBorder, lineWidth: FloatingWidgetMetrics.panelBorderLineWidth)
        )
    }

    private func taskRowView(_ task: TaskItem) -> some View {
        HStack(alignment: .center, spacing: 0) {
            HStack(alignment: .center, spacing: FloatingWidgetMetrics.taskRowHorizontalSpacing) {
                taskCheckbox(isDone: task.isDone)

                VStack(alignment: .leading, spacing: FloatingWidgetMetrics.taskRowTextStackSpacing) {
                    Text(task.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(task.isDone ? FloatingWidgetPalette.taskTitleCompleted : FloatingWidgetPalette.taskTitle)
                        .strikethrough(task.isDone)
                        .modifier(TrackingModifier(value: -0.24))

                    HStack(spacing: FloatingWidgetMetrics.taskRowMetaSpacing) {
                        if let estimatedMinutes = task.estimatedMinutes {
                            HStack(spacing: 3) {
                                Image(systemName: "clock")
                                    .font(.system(size: 9, weight: .bold))
                                Text(languageStore.text(.minutesValue, estimatedMinutes))
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundStyle(FloatingWidgetPalette.durationText)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(FloatingWidgetPalette.durationBg)
                            )
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .layoutPriority(1)
                        }

                        let choiceOption = todoViewModel.choiceField.flatMap { field in
                            task.priority.flatMap { priority in field.options.first { $0.name == priority } }
                        }

                        if task.estimatedMinutes != nil, choiceOption != nil {
                            Text("·")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(FloatingWidgetPalette.metaText)
                        }

                        if let priority = task.priority, let choiceOption {
                            Text(priority)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(TaskChoicePalette.dot(for: choiceOption))
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule().fill(TaskChoicePalette.dot(for: choiceOption).opacity(0.14))
                                )
                                .help(priority)
                        }

                        if choiceOption != nil {
                            Text("·").font(.system(size: 10, weight: .semibold)).foregroundStyle(FloatingWidgetPalette.metaText)
                        }

                        Text(syncText(for: task.syncStatus))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(syncColor(for: task.syncStatus))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()
            }
            .padding(.trailing, FloatingWidgetMetrics.taskRowHorizontalSpacing)
            .contentShape(Rectangle())
            .layoutPriority(1)
            .onTapGesture {
                Task { await todoViewModel.toggleTask(task) }
            }

            HStack(spacing: FloatingWidgetMetrics.taskRowActionSpacing) {
                if todoViewModel.deletingTaskID == task.id {
                    ProgressView()
                        .controlSize(.small)
                }

                if task.syncStatus == .failed {
                    Button(languageStore.text(.retry)) {
                        Task { await todoViewModel.retry(task) }
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(FloatingWidgetPalette.retryText)
                    .buttonStyle(.plain)
                }

                if !task.isDone {
                    PomodoroTaskRowStartAction(viewModel: todoViewModel, task: task)
                }

                Menu {
                    taskActionMenu(for: task)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(FloatingWidgetPalette.todoToolbarText)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(FloatingWidgetPalette.moreBtnBg)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(FloatingWidgetPalette.moreBtnBorder, lineWidth: 1)
                )
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.top, FloatingWidgetMetrics.taskRowTopPadding)
        .padding(.bottom, FloatingWidgetMetrics.taskRowBottomPadding)
        .contextMenu {
            taskActionMenu(for: task)
        }
    }

    private func taskCheckbox(isDone: Bool) -> some View {
        ZStack {
            if isDone {
                Circle()
                    .fill(LinearGradient(
                        colors: [FloatingWidgetPalette.checkboxCompleteTop, FloatingWidgetPalette.checkboxCompleteBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .frame(width: 16, height: 16)

                Image(systemName: "checkmark")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Circle()
                    .stroke(FloatingWidgetPalette.checkboxBorder, lineWidth: 1.5)
                    .background(Circle().fill(FloatingWidgetPalette.checkBg))
                    .frame(width: 16, height: 16)
            }
        }
    }

    @ViewBuilder
    private func taskActionMenu(for task: TaskItem) -> some View {
        Button(languageStore.text(.editTask)) {
            todoViewModel.beginEditing(task)
        }

        Button(languageStore.text(.deleteTask), role: .destructive) {
            taskPendingDeletion = task
        }
    }

    private var journalPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let entry = journalViewModel.entry {
                HStack(spacing: 0) {
                    Text(journalDateString(from: entry.date))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(FloatingWidgetPalette.todoDateTitle)
                        .modifier(TrackingModifier(value: -0.28))
                        .lineLimit(1)

                    Spacer()

                    HStack(spacing: FloatingWidgetMetrics.headerIconButtonSpacing) {
                        Button {
                            Task { await journalViewModel.reloadFromNotion() }
                        } label: {
                            headerActionIcon(systemName: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(FloatingWidgetIconButtonStyle())

                        if let url = journalViewModel.entry?.url {
                            Button {
                                journalViewModel.openInNotion(url)
                            } label: {
                                headerActionIcon(systemName: "arrow.up.forward.square")
                            }
                            .buttonStyle(FloatingWidgetIconButtonStyle())
                        }
                    }
                }
                .padding(.bottom, FloatingWidgetMetrics.journalDateBottomSpacing)
            }

            if journalViewModel.isLoading {
                ProgressView(languageStore.text(.loadingJournal))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                JournalTextEditor(
                    text: $journalViewModel.editorText,
                    fontSize: FloatingWidgetMetrics.journalEditorFontSize,
                    lineSpacing: FloatingWidgetMetrics.journalEditorLineSpacing,
                    contentInsets: FloatingWidgetMetrics.journalEditorInsets,
                    textColor: NSColor(FloatingWidgetPalette.editorText)
                )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: FloatingWidgetMetrics.panelCornerRadius, style: .continuous)
                            .fill(FloatingWidgetPalette.editorBg)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: FloatingWidgetMetrics.panelCornerRadius, style: .continuous)
                            .stroke(FloatingWidgetPalette.editorBorder, lineWidth: FloatingWidgetMetrics.panelBorderLineWidth)
                    )
                    .onChange(of: journalViewModel.editorText) { _, newValue in
                        journalViewModel.scheduleAutosave(text: newValue)
                    }
            }

            HStack(spacing: FloatingWidgetMetrics.journalStatusSpacing) {
                Image(systemName: "clock.arrow.2.circlepath")
                    .font(.system(size: 12, weight: .medium))
                    .opacity(0.7)
                Text(journalStatusText)
                    .font(.system(size: 11, weight: .semibold))
                    .modifier(TrackingModifier(value: -0.11))
                    .foregroundStyle(
                        journalViewModel.errorMessage == nil
                            ? FloatingWidgetPalette.statusText
                            : FloatingWidgetPalette.dangerText
                    )

                Spacer()

                if journalViewModel.entry?.syncStatus == .failed {
                    Button(languageStore.text(.retry)) {
                        Task { await journalViewModel.forceSave() }
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(FloatingWidgetPalette.dangerText)
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, FloatingWidgetMetrics.journalStatusTopSpacing)
        }
    }

    private var emptyTasksView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checklist")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(FloatingWidgetPalette.metaText)

            Text(emptyTasksTitle)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(FloatingWidgetPalette.metaText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var todoTitle: String {
        TodoDateDisplayFormatter.title(
            for: todoViewModel.selectedDate,
            language: languageStore.language
        )
    }

    private var localizedBannerMessage: String? {
        if let bannerMessageKey {
            return languageStore.text(bannerMessageKey)
        }
        return bannerMessage.map { languageStore.text($0) }
    }

    private var emptyTasksTitle: String {
        TodoDateDisplayFormatter.emptyStateTitle(
            for: todoViewModel.selectedDate,
            language: languageStore.language
        )
    }

    private var journalStatusText: String {
        if let errorMessage = journalViewModel.errorMessage {
            return languageStore.text(errorMessage)
        }
        return languageStore.text(journalViewModel.statusMessage ?? .journalAutosaveHint)
    }

    private func syncText(for status: SyncStatus) -> String {
        switch status {
        case .synced:
            languageStore.text(.syncSynced)
        case .syncing:
            languageStore.text(.syncSyncing)
        case .failed:
            languageStore.text(.syncFailed)
        case .localPending:
            languageStore.text(.syncPending)
        }
    }

    private func syncColor(for status: SyncStatus) -> Color {
        switch status {
        case .synced:
            FloatingWidgetPalette.metaText
        case .syncing, .localPending:
            FloatingWidgetPalette.warningText
        case .failed:
            FloatingWidgetPalette.dangerText
        }
    }

    private func journalDateString(from date: Date) -> String {
        TodoDateDisplayFormatter.title(for: date, language: languageStore.language)
    }

    private func headerActionIcon(systemName: String) -> some View {
        Image(systemName: headerActionSystemName(for: systemName))
            .font(.system(size: FloatingWidgetMetrics.headerIconSymbolSize, weight: .regular))
            .foregroundStyle(FloatingWidgetPalette.todoDateTitle)
            .frame(
                width: FloatingWidgetMetrics.headerIconSymbolSize,
                height: FloatingWidgetMetrics.headerIconSymbolSize
            )
            .accessibilityHidden(true)
    }

    private func headerActionSystemName(for systemName: String) -> String {
        switch systemName {
        case "arrow.triangle.2.circlepath":
            return "arrow.clockwise"
        default:
            return systemName
        }
    }
}

private struct FloatingWidgetActionButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isHovered ? FloatingWidgetPalette.actionBtnHoverColor : FloatingWidgetPalette.actionBtnColor)
            .frame(width: 26, height: 26)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(configuration.isPressed
                        ? FloatingWidgetPalette.actionBtnActiveBg
                        : (isHovered ? FloatingWidgetPalette.actionBtnHoverBg : Color.clear))
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.18), value: isHovered)
            .animation(.easeOut(duration: 0.18), value: configuration.isPressed)
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

private struct FloatingWidgetNavButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(FloatingWidgetPalette.todoDateTitle)
            .frame(width: 22, height: 22)
            .background(
                Circle()
                    .fill(configuration.isPressed
                        ? FloatingWidgetPalette.actionBtnHoverBg
                        : Color.clear)
            )
            .contentShape(Circle())
    }
}

private struct FloatingWidgetIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(FloatingWidgetPalette.todoDateTitle)
            .frame(
                width: FloatingWidgetMetrics.headerIconButtonSize,
                height: FloatingWidgetMetrics.headerIconButtonSize
            )
            .background(
                Circle()
                    .fill(configuration.isPressed
                        ? FloatingWidgetPalette.actionBtnHoverBg
                        : Color.clear)
            )
            .contentShape(Circle())
    }
}

private struct JournalTextEditor: NSViewRepresentable {
    @Binding var text: String
    let fontSize: CGFloat
    let lineSpacing: CGFloat
    let contentInsets: EdgeInsets
    let textColor: NSColor

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> OverflowAwareTextScrollView {
        let scrollView = OverflowAwareTextScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.verticalScrollElasticity = .allowed
        scrollView.horizontalScrollElasticity = .none

        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.drawsBackground = false
        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.importsGraphics = false
        textView.textContainerInset = NSSize(width: contentInsets.leading, height: contentInsets.top)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]

        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView
        context.coordinator.apply(configuration: self)
        scrollView.updateScrollerVisibility()
        return scrollView
    }

    func updateNSView(_ scrollView: OverflowAwareTextScrollView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.scrollView = scrollView
        if let textView = scrollView.documentView as? NSTextView {
            context.coordinator.textView = textView
            if textView.string != text {
                textView.string = text
            }
        }
        context.coordinator.apply(configuration: self)
        scrollView.updateScrollerVisibility()
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: JournalTextEditor
        weak var textView: NSTextView?
        weak var scrollView: OverflowAwareTextScrollView?

        init(_ parent: JournalTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            scrollView?.updateScrollerVisibility()
        }

        func apply(configuration: JournalTextEditor) {
            guard let textView else { return }
            textView.font = .systemFont(ofSize: configuration.fontSize)
            textView.textColor = configuration.textColor
            textView.typingAttributes = attributes(for: configuration)
            textView.textStorage?.setAttributes(
                attributes(for: configuration),
                range: NSRange(location: 0, length: textView.string.utf16.count)
            )
            textView.textContainerInset = NSSize(
                width: configuration.contentInsets.leading,
                height: configuration.contentInsets.top
            )
        }

        private func attributes(for configuration: JournalTextEditor) -> [NSAttributedString.Key: Any] {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = configuration.lineSpacing
            return [
                .font: NSFont.systemFont(ofSize: configuration.fontSize),
                .foregroundColor: configuration.textColor,
                .paragraphStyle: paragraphStyle
            ]
        }
    }
}

private final class OverflowAwareTextScrollView: NSScrollView {
    override func layout() {
        super.layout()
        updateScrollerVisibility()
    }

    func updateScrollerVisibility() {
        guard let textView = documentView as? NSTextView else {
            hasVerticalScroller = false
            return
        }

        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        let contentHeight = textView.textContainerInset.height * 2
            + textView.layoutManager!.usedRect(for: textView.textContainer!).height
        let contentOverflows = contentHeight > contentView.bounds.height + 0.5
        hasVerticalScroller = contentOverflows
    }
}

private struct TrackingModifier: ViewModifier {
    let value: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 13.0, *) {
            content.tracking(value)
        } else {
            content
        }
    }
}

struct EditTaskFormCard: View {
    @ObservedObject var viewModel: TodoListViewModel
    @EnvironmentObject private var languageStore: LanguageStore
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isEstimatedMinutesFocused: Bool
    @FocusState private var isTypeSearchFocused: Bool
    @State private var typeSearchText = ""
    @State private var isTypeOptionsPresented = false

    private var selectedTypeOption: NotionSelectOption? {
        viewModel.choiceField?.options.first { $0.name == viewModel.editingPriority }
    }

    private var filteredTypeOptions: [NotionSelectOption] {
        let query = typeSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return viewModel.choiceField?.options ?? [] }
        return (viewModel.choiceField?.options ?? []).filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
    }

    private var typeOptionsListHeight: CGFloat {
        min(CGFloat(filteredTypeOptions.count) * 30, 120)
    }

    var body: some View {
        SlimFormScrollView(usesContentHeight: true) {
            VStack(alignment: .leading, spacing: NewTaskFormMetrics.verticalSpacing) {
            Text(languageStore.text(.editTask))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(NewTaskFormPalette.title)
                .frame(maxWidth: .infinity, alignment: .center)

            VStack(alignment: .leading, spacing: 6) {
                Text(languageStore.text(.taskLabel))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(NewTaskFormPalette.title)

                TextField(languageStore.text(.taskLabel), text: $viewModel.editingTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(NewTaskFormPalette.title)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity)
                    .frame(height: NewTaskFormMetrics.fieldHeight)
                    .background(
                        RoundedRectangle(cornerRadius: NewTaskFormMetrics.fieldCornerRadius, style: .continuous)
                            .fill(NewTaskFormPalette.fieldFill)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: NewTaskFormMetrics.fieldCornerRadius, style: .continuous)
                            .stroke(titleBorderColor(), lineWidth: viewModel.errorMessage == AppMessage(.taskTitleRequired) ? 1.5 : 1)
                    )
                    .disabled(viewModel.isSavingTaskEdit)
                    .focused($isTitleFocused)
                    .onAppear {
                        isTitleFocused = true
                    }

                if viewModel.errorMessage == AppMessage(.taskTitleRequired) {
                    Text(languageStore.text(.taskTitleRequired))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(languageStore.text(.estimatedMinutesLabel))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(NewTaskFormPalette.title)

                HStack(spacing: 0) {
                    TextField(languageStore.text(.estimatedMinutesLabel), text: $viewModel.editingEstimatedMinutesText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(NewTaskFormPalette.title)

                    Spacer()

                    Text(languageStore.text(.minutesLabel))
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(NewTaskFormPalette.meta)
                }
                .padding(.leading, 12)
                .padding(.trailing, 12)
                .frame(maxWidth: .infinity)
                .frame(height: NewTaskFormMetrics.fieldHeight)
                .background(
                    RoundedRectangle(cornerRadius: NewTaskFormMetrics.fieldCornerRadius, style: .continuous)
                        .fill(NewTaskFormPalette.fieldFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: NewTaskFormMetrics.fieldCornerRadius, style: .continuous)
                        .stroke(estimatedMinutesBorderColor(), lineWidth: viewModel.editingEstimatedMinutesError == nil ? 1 : 1.5)
                )
                .disabled(viewModel.isSavingTaskEdit)
                .focused($isEstimatedMinutesFocused)

                if let estimatedMinutesError = viewModel.editingEstimatedMinutesError {
                    Text(languageStore.text(estimatedMinutesError))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if let choiceField = viewModel.choiceField {
                VStack(alignment: .leading, spacing: 6) {
                    Text(choiceField.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(NewTaskFormPalette.title)

                    HStack(spacing: 0) {
                        Group {
                            if let selectedTypeOption, !isTypeOptionsPresented {
                                Circle()
                                    .fill(TaskChoicePalette.dot(for: selectedTypeOption))
                                    .frame(width: 8, height: 8)
                            } else {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(NewTaskFormPalette.meta)
                            }
                        }
                        .frame(width: 32)

                        TextField("搜索或选择类型", text: $typeSearchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(NewTaskFormPalette.title)
                            .focused($isTypeSearchFocused)
                            .simultaneousGesture(TapGesture().onEnded {
                                presentTypeOptions()
                            })

                        Button {
                            toggleTypeOptions()
                        } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(NewTaskFormPalette.meta)
                                .frame(width: 34, height: NewTaskFormMetrics.fieldHeight)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(NewTaskFormPalette.fieldBorder)
                                .frame(width: 1)
                                .padding(.vertical, 7)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: NewTaskFormMetrics.fieldHeight)
                    .background(
                        RoundedRectangle(cornerRadius: NewTaskFormMetrics.fieldCornerRadius, style: .continuous)
                            .fill(NewTaskFormPalette.fieldFill)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: NewTaskFormMetrics.fieldCornerRadius, style: .continuous)
                            .stroke(typePickerBorderColor(), lineWidth: 1)
                    )
                    .disabled(viewModel.isSavingTaskEdit)

                    if isTypeOptionsPresented {
                        typeOptionsMenu
                            .disabled(viewModel.isSavingTaskEdit)
                    }
                }
            }

            HStack(spacing: 8) {
                Button(languageStore.text(.cancel)) {
                    viewModel.cancelEditing()
                }
                .buttonStyle(NewTaskSecondaryButtonStyle())
                .disabled(viewModel.isSavingTaskEdit)

                Button(languageStore.text(.save)) {
                    Task {
                        await viewModel.saveTaskEdit()
                    }
                }
                .buttonStyle(NewTaskPrimaryButtonStyle())
                .disabled(viewModel.isSavingTaskEdit)
            }
            .padding(.top, 4)
            }
            .padding(NewTaskFormMetrics.contentPadding)
        }
        .frame(width: NewTaskFormMetrics.cardWidth)
        .frame(minHeight: NewTaskFormMetrics.cardMinHeight, maxHeight: NewTaskFormMetrics.cardMaxHeight)
        .background(
            RoundedRectangle(cornerRadius: NewTaskFormMetrics.cardCornerRadius, style: .continuous)
                .fill(NewTaskFormPalette.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: NewTaskFormMetrics.cardCornerRadius, style: .continuous)
                .stroke(NewTaskFormPalette.cardBorder, lineWidth: 1)
        )
        .shadow(color: NewTaskFormPalette.cardShadow, radius: 18, y: 10)
        .onAppear {
            typeSearchText = viewModel.editingPriority ?? ""
        }
        .onChange(of: viewModel.editingPriority) { _, newSelection in
            guard !isTypeOptionsPresented else { return }
            typeSearchText = newSelection ?? ""
        }
    }

    private var typeOptionsMenu: some View {
        VStack(spacing: 2) {
            Button {
                clearEditingType()
            } label: {
                typeOptionRow(title: "未选择", option: nil)
            }
            .buttonStyle(.plain)

            if filteredTypeOptions.isEmpty {
                Text("没有匹配的类型")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(NewTaskFormPalette.meta)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 2) {
                        ForEach(filteredTypeOptions, id: \.name) { option in
                            Button {
                                selectEditingType(option)
                            } label: {
                                typeOptionRow(title: option.name, option: option)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(height: typeOptionsListHeight)
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: NewTaskFormMetrics.fieldCornerRadius, style: .continuous)
                .fill(NewTaskFormPalette.fieldFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: NewTaskFormMetrics.fieldCornerRadius, style: .continuous)
                .stroke(NewTaskFormPalette.fieldBorder, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func typeOptionRow(title: String, option: NotionSelectOption?) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(TaskChoicePalette.dot(for: option))
                .frame(width: 8, height: 8)
            Text(title)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(NewTaskFormPalette.title)
            Spacer()
            if viewModel.editingPriority == option?.name {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(NewTaskFormPalette.focusBorder)
            }
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .frame(height: 28)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(viewModel.editingPriority == option?.name ? NewTaskFormPalette.focusBorder.opacity(0.10) : Color.clear)
        )
    }

    private func presentTypeOptions() {
        guard !isTypeOptionsPresented else { return }
        typeSearchText = ""
        isTypeOptionsPresented = true
    }

    private func toggleTypeOptions() {
        if isTypeOptionsPresented {
            dismissTypeOptions()
        } else {
            presentTypeOptions()
            isTypeSearchFocused = true
        }
    }

    private func dismissTypeOptions() {
        isTypeOptionsPresented = false
        isTypeSearchFocused = false
        typeSearchText = viewModel.editingPriority ?? ""
    }

    private func clearEditingType() {
        viewModel.editingPriority = nil
        typeSearchText = ""
        isTypeOptionsPresented = false
        isTypeSearchFocused = false
    }

    private func selectEditingType(_ option: NotionSelectOption) {
        viewModel.editingPriority = option.name
        typeSearchText = option.name
        isTypeOptionsPresented = false
        isTypeSearchFocused = false
    }

    private func typePickerBorderColor() -> Color {
        isTypeSearchFocused || isTypeOptionsPresented
            ? NewTaskFormPalette.focusBorder
            : NewTaskFormPalette.fieldBorder
    }

    private func titleBorderColor() -> Color {
        if viewModel.errorMessage == AppMessage(.taskTitleRequired) {
            return NewTaskFormPalette.validationBorder
        }
        if isTitleFocused {
            return NewTaskFormPalette.focusBorder
        }
        return NewTaskFormPalette.fieldBorder
    }

    private func estimatedMinutesBorderColor() -> Color {
        if viewModel.editingEstimatedMinutesError != nil {
            return NewTaskFormPalette.validationBorder
        }
        if isEstimatedMinutesFocused {
            return NewTaskFormPalette.focusBorder
        }
        return NewTaskFormPalette.fieldBorder
    }
}

#Preview("内容 / 加载中") {
    ContentView(rootViewModel: makePreviewRootViewModel(state: .loading))
        .frame(width: 340, height: 460)
}

#Preview("内容 / 欢迎") {
    ContentView(rootViewModel: makePreviewRootViewModel(state: .welcome))
        .frame(width: 340, height: 460)
}

#Preview("内容 / 初始配置") {
    ContentView(rootViewModel: makePreviewRootViewModel(state: .onboarding))
        .frame(width: 340, height: 460)
}

#Preview("内容 / 主界面") {
    ContentView(rootViewModel: makePreviewRootViewModel(state: .widget))
        .frame(width: 340, height: 460)
}

#Preview("初始配置") {
    OnboardingView(viewModel: makePreviewOnboardingViewModel(), mode: .onboarding)
        .frame(width: 340, height: 460)
}

#Preview("设置") {
    OnboardingView(viewModel: makePreviewOnboardingViewModel(), mode: .settings, onBack: {})
        .frame(width: 340, height: 460)
}

#Preview("悬浮组件") {
    FloatingWidgetView(
        todoViewModel: makePreviewTodoListViewModel(),
        journalViewModel: makePreviewJournalViewModel(),
        refreshAction: {},
        bannerMessage: nil,
        bannerMessageKey: .workspaceSynced
    )
    .frame(width: 340, height: 460)
}

private enum PreviewRootState {
    case loading
    case welcome
    case onboarding
    case widget
}

@MainActor
private func makePreviewRootViewModel(state: PreviewRootState) -> RootViewModel {
    let rootViewModel = RootViewModel(repository: makePreviewRepository(), openURL: { _ in })

    switch state {
    case .loading:
        rootViewModel.screen = .loading
    case .welcome:
        rootViewModel.screen = .welcome
    case .onboarding:
        rootViewModel.screen = .onboarding
        rootViewModel.onboardingViewModel.token = "secret_preview_token"
        rootViewModel.onboardingViewModel.tasksDatabaseInput = "任务数据库 ID"
        rootViewModel.onboardingViewModel.journalDatabaseInput = "日记数据库 ID"
        rootViewModel.onboardingViewModel.statusMessageKey = .keychainTokenFound
    case .widget:
        rootViewModel.screen = .widget
        rootViewModel.bannerMessageKey = .workspaceSynced
        rootViewModel.todoListViewModel.tasks = previewTasks
        rootViewModel.journalViewModel.entry = previewJournalEntry
        rootViewModel.journalViewModel.editorText = previewJournalEntry.contentText
        rootViewModel.journalViewModel.statusMessage = .journalSavedToNotion
    }

    return rootViewModel
}

@MainActor
private func makePreviewOnboardingViewModel() -> OnboardingViewModel {
    let viewModel = OnboardingViewModel(repository: makePreviewRepository())
    viewModel.token = "secret_preview_token"
    viewModel.tasksDatabaseInput = "任务数据库 ID"
    viewModel.journalDatabaseInput = "日记数据库 ID"
    viewModel.statusMessage = AppMessage(.missingToken)
    return viewModel
}

@MainActor
private func makePreviewTodoListViewModel() -> TodoListViewModel {
    let viewModel = TodoListViewModel(repository: makePreviewRepository(), hasPriorityField: true, openURL: { _ in })
    viewModel.tasks = previewTasks
    return viewModel
}

@MainActor
private func makePreviewJournalViewModel() -> JournalViewModel {
    let viewModel = JournalViewModel(repository: makePreviewRepository(), openURL: { _ in })
    viewModel.entry = previewJournalEntry
    viewModel.editorText = previewJournalEntry.contentText
    viewModel.statusMessage = .journalAutosaveHint
    return viewModel
}

@MainActor
private func makePreviewRepository() -> NotionRepository {
    let previewRootURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("WidgetToDoPreview", isDirectory: true)

    return NotionRepository(
        tokenStore: KeychainTokenStore(),
        settingsStore: try! SettingsStore(baseURL: previewRootURL),
        cache: try! SQLiteCache(baseURL: previewRootURL),
        notionClient: NotionClient()
    )
}

private let previewTasks: [TaskItem] = [
    TaskItem(
        id: "preview-task-1",
        title: "完成菜单栏悬浮组件预览",
        isDone: false,
        priority: "高",
        estimatedMinutes: 60,
        date: .now,
        url: URL(string: "https://www.notion.so"),
        syncStatus: .synced
    ),
    TaskItem(
        id: "preview-task-2",
        title: "重试失败的日记同步场景",
        isDone: false,
        priority: "中",
        estimatedMinutes: 30,
        date: .now.addingTimeInterval(1800),
        url: nil,
        syncStatus: .failed
    ),
    TaskItem(
        id: "preview-task-3",
        title: "归档过期实验项",
        isDone: true,
        priority: "低",
        estimatedMinutes: 120,
        date: .now.addingTimeInterval(3600),
        url: nil,
        syncStatus: .localPending
    )
]

private let previewJournalEntry = JournalEntry(
    id: "preview-journal-entry",
    title: "日记",
    date: .now,
    contentText: """
    已完成悬浮组件的 SwiftUI 预览。

    接下来：
    - 确认 Canvas 能渲染所有状态
    - 保持运行时逻辑不变
    """,
    url: URL(string: "https://www.notion.so"),
    syncStatus: .synced
)
