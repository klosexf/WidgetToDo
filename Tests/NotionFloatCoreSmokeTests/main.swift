import Foundation
import NotionFloatCore

struct SmokeTestFailure: Error, CustomStringConvertible {
    let description: String
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw SmokeTestFailure(description: message)
    }
}

@main
struct NotionFloatCoreSmokeTestsRunner {
    static func main() async throws {
        do {
            try databaseReferenceParsesRawUUID()
            try databaseReferenceParsesDatabaseURL()
            try taskFieldValidationReportsMissingRequiredFields()
            try taskSortingKeepsIncompleteAndHigherPriorityFirst()
            try journalContentBuilderConvertsLinesToParagraphBlocks()
            try notionClientHttpErrorExposesReadableDescription()
            try notionRepositoryValidationErrorExposesReadableDescription()
            try notionRepositoryBuildsTasksDatabasePageURL()
            try todoListViewModelDoesNotSynchronouslyBridgeNestedObjectWillChange()
            try todoHeaderOpenButtonTargetsTasksDatabasePage()
            try journalHeaderContainsManualSyncButton()
            try topBarDoesNotShowExpandButton()
            try welcomeViewUsesDedicatedIllustrationAssetAndCallback()
            try configurationFormContainsSettingsHelpAndExtractionCopy()
            try newTaskFormUsesWidgetCardStyle()
            try onboardingVisualAlignmentKeepsExistingBehaviorContract()
            try settingsResetFlowReturnsUserToWelcome()
            try statusBarMenuContainsSettingsEntry()
            try todoDateTitleUsesChineseDateWithoutTodaySpecialCase()
            try floatingWindowManagerDoesNotDependOnGlobalMouseUpMonitoring()
            try floatingPanelDoesNotSynchronouslyActivateDuringEventDispatch()
            try await notionClientBuildsDatabaseSchemaURLWithoutQuery()
            try await notionClientPreservesQueryItemsInBlockChildrenURL()
            print("All smoke tests passed.")
        } catch {
            fputs("Smoke test failed: \(error)\n", stderr)
            Foundation.exit(1)
        }
    }

    static func databaseReferenceParsesRawUUID() throws {
        let parsed = NotionDatabaseReference.parse("12345678-1234-1234-1234-1234567890ab")
        try expect(
            parsed == NotionDatabaseReference(rawValue: "12345678-1234-1234-1234-1234567890ab"),
            "raw UUID parsing should preserve canonical database ID"
        )
    }

    static func databaseReferenceParsesDatabaseURL() throws {
        let parsed = NotionDatabaseReference.parse("https://www.notion.so/My-Tasks-123456781234123412341234567890ab?v=abcdef")
        try expect(
            parsed == NotionDatabaseReference(rawValue: "12345678-1234-1234-1234-1234567890ab"),
            "database URL parsing should extract a canonical UUID"
        )
    }

    static func taskFieldValidationReportsMissingRequiredFields() throws {
        let issues = FieldValidator.validate(
            [
                NotionPropertySchema(name: "Name", type: "title"),
                NotionPropertySchema(name: "Done", type: "checkbox")
            ],
            for: .tasks
        )

        try expect(
            issues.map(\.message) == ["缺少必填字段：Date(date)"],
            "task schema validation should report only the missing required field"
        )
    }

    static func taskSortingKeepsIncompleteAndHigherPriorityFirst() throws {
        let formatter = ISO8601DateFormatter()
        let tasks = [
            TaskItem(
                id: "done-low",
                title: "done low",
                isDone: true,
                priority: "Low",
                date: formatter.date(from: "2026-05-17T12:00:00Z")!,
                url: nil,
                syncStatus: .synced
            ),
            TaskItem(
                id: "todo-medium",
                title: "todo medium",
                isDone: false,
                priority: "Medium",
                date: formatter.date(from: "2026-05-17T09:00:00Z")!,
                url: nil,
                syncStatus: .synced
            ),
            TaskItem(
                id: "todo-high",
                title: "todo high",
                isDone: false,
                priority: "High",
                date: formatter.date(from: "2026-05-17T10:00:00Z")!,
                url: nil,
                syncStatus: .synced
            )
        ]

        try expect(
            TaskSorting.sort(tasks).map(\.id) == ["todo-high", "todo-medium", "done-low"],
            "task sorting should prioritize incomplete tasks, then higher priority, then earlier date"
        )
    }

    static func journalContentBuilderConvertsLinesToParagraphBlocks() throws {
        let payloads = JournalContentBuilder.makeParagraphPayloads(from: "Line 1\n\nLine 3")
        let jsonData = try JSONSerialization.data(withJSONObject: payloads)
        guard let json = String(data: jsonData, encoding: .utf8) else {
            throw SmokeTestFailure(description: "journal payload should be valid UTF-8 JSON")
        }

        try expect(json.contains("\"type\":\"paragraph\""), "journal payload should contain paragraph blocks")
        try expect(json.contains("Line 1"), "journal payload should contain the first line")
        try expect(json.contains("Line 3"), "journal payload should contain the later line")
        try expect(payloads.count == 2, "journal payload should drop blank lines and emit two paragraphs")
    }

    static func notionClientHttpErrorExposesReadableDescription() throws {
        let error = NotionClientError.httpError(
            statusCode: 401,
            message: #"{"object":"error","status":401,"code":"unauthorized","message":"API token is invalid."}"#
        )

        try expect(
            error.localizedDescription == "Notion 请求失败（HTTP 401）：API token is invalid.",
            "HTTP errors should surface the status code and Notion message"
        )
    }

    static func notionRepositoryValidationErrorExposesReadableDescription() throws {
        let error = NotionRepositoryError.validationFailed(
            [
                ValidationIssue(message: "缺少必填字段：Name(title)"),
                ValidationIssue(message: "缺少必填字段：Date(date)")
            ]
        )

        try expect(
            error.localizedDescription == "数据库字段校验失败：缺少必填字段：Name(title)；缺少必填字段：Date(date)",
            "repository validation errors should join validation issues into one readable message"
        )
    }

    static func notionRepositoryBuildsTasksDatabasePageURL() throws {
        let databaseID = "12345678-1234-1234-1234-1234567890ab"
        let databaseURL = URL(string: "https://www.notion.so/\(databaseID.replacingOccurrences(of: "-", with: ""))")

        try expect(
            databaseURL?.absoluteString == "https://www.notion.so/123456781234123412341234567890ab",
            "task database navigation should target the database root URL instead of a task page URL"
        )
    }

    static func floatingWindowManagerDoesNotDependOnGlobalMouseUpMonitoring() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let managerURL = rootURL
            .appendingPathComponent("WidgetToDo")
            .appendingPathComponent("FloatingWindowManager.swift")
        let source = try String(contentsOf: managerURL, encoding: .utf8)

        try expect(
            !source.contains("addGlobalMonitorForEvents"),
            "floating window drag completion must not rely on global mouse-up monitoring"
        )
        try expect(
            source.contains("if event.type == .leftMouseUp"),
            "floating window drag completion should clear drag state on local leftMouseUp"
        )
    }

    static func todoListViewModelDoesNotSynchronouslyBridgeNestedObjectWillChange() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewModelURL = rootURL
            .appendingPathComponent("WidgetToDo")
            .appendingPathComponent("TodoListViewModel.swift")
        let source = try String(contentsOf: viewModelURL, encoding: .utf8)

        try expect(
            !source.contains("self?.objectWillChange.send()"),
            "todo list view model should not synchronously forward nested objectWillChange events"
        )
    }

    static func todoHeaderOpenButtonTargetsTasksDatabasePage() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let contentViewURL = rootURL
            .appendingPathComponent("WidgetToDo")
            .appendingPathComponent("ContentView.swift")
        let source = try String(contentsOf: contentViewURL, encoding: .utf8)

        try expect(
            source.contains("todoViewModel.tasksDatabaseURL != nil"),
            "todo header open button should depend on the tasks database URL being available"
        )
        try expect(
            source.contains("todoViewModel.openTasksDatabaseInNotion()"),
            "todo header open button should open the tasks database page"
        )
        try expect(
            !source.contains("firstTaskWithUrl"),
            "todo header open button must not reuse the first task page URL"
        )
    }

    static func journalHeaderContainsManualSyncButton() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let contentViewURL = rootURL
            .appendingPathComponent("WidgetToDo")
            .appendingPathComponent("ContentView.swift")
        let source = try String(contentsOf: contentViewURL, encoding: .utf8)

        try expect(
            source.contains("private var journalToolbar: some View"),
            "journal tab should define a dedicated header toolbar"
        )
        try expect(
            source.contains("Image(systemName: \"arrow.triangle.2.circlepath\")"),
            "journal header should expose the same sync icon used by the todo header"
        )
        try expect(
            source.contains("await journalViewModel.reloadFromNotion()"),
            "journal header sync button should reload the current journal from Notion"
        )
        let journalViewModelURL = rootURL
            .appendingPathComponent("WidgetToDo")
            .appendingPathComponent("JournalViewModel.swift")
        let journalViewModelSource = try String(contentsOf: journalViewModelURL, encoding: .utf8)
        try expect(
            journalViewModelSource.contains("func reloadFromNotion() async"),
            "journal view model should define an explicit reload entry point"
        )
        try expect(
            journalViewModelSource.contains("autosaveTask?.cancel()"),
            "reloading from Notion should cancel any pending autosave before overwriting local text"
        )
        try expect(
            journalViewModelSource.contains("await load()"),
            "reloading from Notion should reuse the existing journal load path"
        )
    }

    static func topBarDoesNotShowExpandButton() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let contentViewURL = rootURL
            .appendingPathComponent("WidgetToDo")
            .appendingPathComponent("ContentView.swift")
        let source = try String(contentsOf: contentViewURL, encoding: .utf8)

        try expect(
            !source.contains("Image(systemName: \"arrow.up.left.and.arrow.down.right\")"),
            "top bar should not render the expand button in todo or journal tabs"
        )
    }

    static func statusBarMenuContainsSettingsEntry() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let statusBarURL = rootURL
            .appendingPathComponent("WidgetToDo")
            .appendingPathComponent("StatusBarController.swift")
        let source = try String(contentsOf: statusBarURL, encoding: .utf8)

        try expect(
            source.contains("private let onSettings: () -> Void"),
            "status bar controller should expose a settings callback"
        )
        try expect(
            source.contains("NSMenuItem(title: \"设置\""),
            "status bar menu should include a settings item"
        )
        try expect(
            source.contains("effectiveAppearance"),
            "status bar icon color should adapt to menu bar appearance (light/dark)"
        )
        try expect(
            source.contains("button.layer?.addSublayer"),
            "status bar icon should add shape layers as sublayers of the button"
        )
        try expect(
            source.contains("button.sendAction(on: .leftMouseUp)"),
            "status bar item should handle left mouse click via button action"
        )
        try expect(
            source.contains("NSEvent.addLocalMonitorForEvents(matching: .rightMouseUp)"),
            "status bar item should handle right mouse click via local event monitor since NSStatusBarButton ignores sendAction for right click"
        )
        try expect(
            source.contains("NSMenu.popUpContextMenu(menu, with: event, for: button)"),
            "status bar item should pop the menu using NSMenu.popUpContextMenu with the triggering event"
        )
        try expect(
            source.contains("item.length = NSStatusItem.variableLength"),
            "status bar item should reserve enough width for the visible title and icon"
        )
        try expect(
            !source.contains("button.title = \" Notion\""),
            "status bar item should no longer rely on the previous text-only Notion title path"
        )
        try expect(
            source.contains("#selector(openSettings)"),
            "settings menu item should call the settings action"
        )
    }

    static func configurationFormContainsSettingsHelpAndExtractionCopy() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let contentViewURL = rootURL
            .appendingPathComponent("WidgetToDo")
            .appendingPathComponent("ContentView.swift")
        let viewModelURL = rootURL
            .appendingPathComponent("WidgetToDo")
            .appendingPathComponent("OnboardingViewModel.swift")
        let source = try String(contentsOf: contentViewURL, encoding: .utf8)
        let viewModelSource = try String(contentsOf: viewModelURL, encoding: .utf8)

        try expect(
            source.contains("SecureField(\"\", text: $viewModel.token"),
            "configuration form should keep the secure token field binding"
        )
        try expect(
            source.contains("accessibilityLabel(\"Notion Token\")"),
            "configuration form should keep an accessibility label for the token field"
        )
        try expect(
            source.contains("Text(\"如何获取？\")"),
            "configuration form should include token help copy"
        )
        try expect(
            source.contains("Text(\"粘贴整个URL自动提取\")"),
            "database sections should explain automatic URL extraction"
        )
        try expect(
            source.contains("mode: .onboarding,") && source.contains("rootViewModel.screen = .welcome"),
            "onboarding flow should expose a back action that returns to welcome"
        )
        try expect(
            viewModelSource.contains("ConfigurationInputNormalizer.normalizeDatabaseInput"),
            "configuration view model should normalize pasted database URLs"
        )
    }

    static func newTaskFormUsesWidgetCardStyle() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let formURL = rootURL
            .appendingPathComponent("WidgetToDo")
            .appendingPathComponent("NewTaskFormCard.swift")
        let source = try String(contentsOf: formURL, encoding: .utf8)
        let normalized = source.replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)

        try expect(
            normalized.contains("TextField(\"标题(必填)\"") && normalized.contains("text:$viewModel.title"),
            "new task form should keep the title binding"
        )
        try expect(
            normalized.contains("DatePicker(\"\"") &&
                normalized.contains("selection:$viewModel.taskDate") &&
                normalized.contains("displayedComponents:.date"),
            "new task form should keep the compact date binding"
        )
        try expect(
            normalized.contains("viewModel.dismissForm()"),
            "new task form should keep cancel behavior"
        )
        try expect(
            normalized.contains("viewModel.submit()"),
            "new task form should keep submit behavior"
        )
        try expect(
            normalized.contains("viewModel.formState==.validationFailed"),
            "new task form should keep validation state rendering"
        )
        try expect(
            normalized.contains("ShakeEffect(animatableData:viewModel.shakeAttempts)"),
            "new task form should keep the shake effect"
        )
        try expect(
            !normalized.contains(".background(.regularMaterial"),
            "new task form should no longer use the generic regularMaterial card"
        )
    }

    static func onboardingVisualAlignmentKeepsExistingBehaviorContract() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let contentViewURL = rootURL
            .appendingPathComponent("WidgetToDo")
            .appendingPathComponent("ContentView.swift")
        let source = try String(contentsOf: contentViewURL, encoding: .utf8)

        func functionScope(in source: String, signature: String) -> Substring? {
            guard let signatureRange = source.range(of: signature) else {
                return nil
            }

            let searchStart = signatureRange.lowerBound
            let endCandidates = [
                source.range(of: "\n    private var ", range: signatureRange.upperBound..<source.endIndex)?.lowerBound,
                source.range(of: "\n    private func ", range: signatureRange.upperBound..<source.endIndex)?.lowerBound,
                source.range(of: "\n    func ", range: signatureRange.upperBound..<source.endIndex)?.lowerBound,
                source.range(of: "\n}\n\nstruct ", range: signatureRange.upperBound..<source.endIndex)?.lowerBound,
            ].compactMap { $0 }

            let endIndex = endCandidates.min() ?? source.endIndex
            return source[searchStart..<endIndex]
        }

        guard let tokenSectionScope = functionScope(
            in: source,
            signature: "private var tokenSection: some View"
        ) else {
            throw SmokeTestFailure(
                description: "onboarding alignment refresh must keep a dedicated tokenSection view"
            )
        }
        guard let databaseSectionScope = functionScope(
            in: source,
            signature: "private func databaseSection(title: String, placeholder: String, text: Binding<String>, normalize: @escaping () -> Void) -> some View"
        ) else {
            throw SmokeTestFailure(
                description: "onboarding alignment refresh must keep the shared databaseSection builder"
            )
        }
        guard let primaryButtonScope = functionScope(
            in: source,
            signature: "private var primaryButton: some View"
        ) else {
            throw SmokeTestFailure(
                description: "onboarding alignment refresh must keep a dedicated primaryButton view"
            )
        }

        try expect(
            tokenSectionScope.contains("SecureField("),
            "onboarding alignment refresh must keep the secure token field"
        )
        try expect(
            tokenSectionScope.contains("isShowingTokenHelp = true"),
            "onboarding alignment refresh must keep the token help toggle action"
        )
        try expect(
            source.contains("normalize: viewModel.normalizeTasksDatabaseInput"),
            "onboarding alignment refresh must keep the tasks database normalization hook"
        )
        try expect(
            source.contains("normalize: viewModel.normalizeJournalDatabaseInput"),
            "onboarding alignment refresh must keep the journal database normalization hook"
        )
        try expect(
            databaseSectionScope.contains(".onChange(of: text.wrappedValue)"),
            "onboarding alignment refresh must keep the generic text-change normalization trigger"
        )
        try expect(
            databaseSectionScope.contains("normalize()"),
            "onboarding alignment refresh must keep the generic normalization invocation path"
        )
        try expect(
            primaryButtonScope.contains("await viewModel.validateAndSave()"),
            "onboarding alignment refresh must keep the validate-and-save action"
        )
        try expect(
            primaryButtonScope.contains("mode == .settings ? \"保存设置\" : \"验证并继续\""),
            "onboarding alignment refresh must keep the existing CTA copy contract"
        )
    }

    static func settingsResetFlowReturnsUserToWelcome() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let contentViewURL = rootURL
            .appendingPathComponent("WidgetToDo")
            .appendingPathComponent("ContentView.swift")
        let viewModelURL = rootURL
            .appendingPathComponent("WidgetToDo")
            .appendingPathComponent("OnboardingViewModel.swift")
        let contentSource = try String(contentsOf: contentViewURL, encoding: .utf8)
        let viewModelSource = try String(contentsOf: viewModelURL, encoding: .utf8)

        func functionScope(in source: String, signature: String) -> Substring? {
            guard let signatureRange = source.range(of: signature) else {
                return nil
            }

            let searchStart = signatureRange.lowerBound
            let endCandidates = [
                source.range(of: "\n    func ", range: signatureRange.upperBound..<source.endIndex)?.lowerBound,
                source.range(of: "\n}\n\nstruct ", range: signatureRange.upperBound..<source.endIndex)?.lowerBound,
            ].compactMap { $0 }

            let endIndex = endCandidates.min() ?? source.endIndex
            return source[searchStart..<endIndex]
        }

        try expect(
            contentSource.contains("初始化配置"),
            "settings UI should expose the reset configuration entry point"
        )
        try expect(
            contentSource.contains("不会清除本地缓存的任务和日记内容"),
            "settings reset confirmation should explain local cache remains intact"
        )
        try expect(
            contentSource.contains("showingResetConfirmation"),
            "settings reset flow should track confirmation presentation state"
        )
        try expect(
            contentSource.contains("isResetActionPending"),
            "settings reset flow should keep a local pending flag while the confirmed reset task is in flight"
        )
        try expect(
            contentSource.contains("await rootViewModel.resetConfigurationFromSettings()"),
            "settings reset flow should invoke the root view model reset action"
        )
        guard let settingsBackRowScope = functionScope(
            in: contentSource,
            signature: "private var settingsBackRow: some View"
        ) else {
            throw SmokeTestFailure(
                description: "settings reset flow should keep a dedicated settingsBackRow view"
            )
        }
        try expect(
            settingsBackRowScope.contains(".disabled(viewModel.isWorking || isResetActionPending)"),
            "settingsBackRow should be disabled while reset is running or locally pending"
        )
        guard let rootResetScope = functionScope(
            in: contentSource,
            signature: "func resetConfigurationFromSettings() async"
        ) else {
            throw SmokeTestFailure(
                description: "settings reset flow should define a dedicated root reset coordinator"
            )
        }
        try expect(
            rootResetScope.contains("screenBeforeSettings = .welcome"),
            "root reset coordinator should restore settings return state to welcome inside resetConfigurationFromSettings()"
        )
        try expect(
            rootResetScope.contains("screen = .welcome"),
            "root reset coordinator should route back to welcome inside resetConfigurationFromSettings()"
        )
        try expect(
            rootResetScope.contains("try await onboardingViewModel.resetConfigurationForRestart()"),
            "root reset coordinator should only restore welcome after awaiting onboardingViewModel.resetConfigurationForRestart()"
        )
        try expect(
            viewModelSource.contains("try await repository.resetConfiguration()"),
            "onboarding view model reset should delegate to repository.resetConfiguration"
        )
    }

    static func todoDateTitleUsesChineseDateWithoutTodaySpecialCase() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let contentViewURL = rootURL
            .appendingPathComponent("WidgetToDo")
            .appendingPathComponent("ContentView.swift")
        let source = try String(contentsOf: contentViewURL, encoding: .utf8)

        try expect(
            source.contains("TodoDateDisplayFormatter.title(for: todoViewModel.selectedDate)"),
            "todo date title should delegate to the shared formatter"
        )
        try expect(
            source.contains("TodoDateDisplayFormatter.emptyStateTitle(for: todoViewModel.selectedDate)"),
            "todo empty state should delegate to the shared formatter"
        )
        try expect(
            source.contains("private let todoDateTitleWidth: CGFloat = 104"),
            "todo date title should reserve a fixed width so today and non-today labels align"
        )
        try expect(
            source.contains(".frame(width: todoDateTitleWidth, alignment: .leading)"),
            "todo date title should render inside the fixed-width frame"
        )
        try expect(
            source.contains(".lineLimit(1)"),
            "todo date title should be constrained to a single line"
        )
        try expect(
            source.contains(".minimumScaleFactor(0.8)"),
            "todo date title should scale down before wrapping"
        )
        try expect(
            source.contains(".allowsTightening(true)"),
            "todo date title should tighten glyph spacing before truncation"
        )
        try expect(
            source.contains(".frame(height: 28)"),
            "todo date title should keep a stable vertical slot height"
        )
        try expect(
            source.contains("private let jumpToTodayWidth: CGFloat = 56"),
            "jump-to-today control should reserve a stable slot width"
        )
    }

    static func welcomeViewUsesDedicatedIllustrationAssetAndCallback() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let assetSetURL = rootURL
            .appendingPathComponent("WidgetToDo")
            .appendingPathComponent("Assets.xcassets")
            .appendingPathComponent("WelcomeIllustration.imageset")
        let assetContentsURL = assetSetURL.appendingPathComponent("Contents.json")
        let assetImageURL = assetSetURL.appendingPathComponent("welcome-illustration.png")
        let welcomeViewURL = rootURL
            .appendingPathComponent("WidgetToDo")
            .appendingPathComponent("WelcomeView.swift")
        let source = try String(contentsOf: welcomeViewURL, encoding: .utf8)
        let fileManager = FileManager.default

        try expect(
            source.contains("Button {") && source.contains("onStartConfig()"),
            "welcome view should keep the existing start-config callback wiring"
        )
        try expect(
            source.contains("Image(\"WelcomeIllustration\")"),
            "welcome view should render the dedicated asset-backed illustration"
        )
        try expect(
            fileManager.fileExists(atPath: assetContentsURL.path),
            "welcome illustration asset set should include Contents.json"
        )
        try expect(
            fileManager.fileExists(atPath: assetImageURL.path),
            "welcome illustration asset set should include the welcome illustration PNG"
        )
        try expect(
            !source.contains(".buttonStyle(.borderedProminent)"),
            "welcome CTA should no longer rely on the default bordered prominent style"
        )
    }

    static func floatingPanelDoesNotSynchronouslyActivateDuringEventDispatch() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let managerURL = rootURL
            .appendingPathComponent("WidgetToDo")
            .appendingPathComponent("FloatingWindowManager.swift")
        let source = try String(contentsOf: managerURL, encoding: .utf8)

        try expect(
            !source.contains("NSApp.activate(ignoringOtherApps: true)"),
            "floating panel should avoid manual app activation from sendEvent to prevent event-path priority inversions"
        )
        try expect(
            !source.contains("RunLoop.main.perform"),
            "floating panel should not enqueue deferred activation work from sendEvent"
        )
    }

    static func notionClientPreservesQueryItemsInBlockChildrenURL() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [CapturingURLProtocol.self]
        let session = URLSession(configuration: config)
        let client = NotionClient(session: session)

        CapturingURLProtocol.reset()
        _ = try await client.fetchJournalText(pageID: "1234-5678", token: "secret_test_token")

        guard let requestURL = CapturingURLProtocol.lastRequest?.url else {
            throw SmokeTestFailure(description: "expected fetchJournalText to issue a request")
        }

        try expect(
            requestURL.absoluteString == "https://api.notion.com/v1/blocks/1234-5678/children?page_size=100",
            "block children requests should keep page_size as a query parameter"
        )
    }

    static func notionClientBuildsDatabaseSchemaURLWithoutQuery() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [CapturingURLProtocol.self]
        let session = URLSession(configuration: config)
        let client = NotionClient(session: session)

        CapturingURLProtocol.reset()
        CapturingURLProtocol.responseBody = #"{"properties":{}}"#.data(using: .utf8)!
        _ = try await client.fetchDatabaseSchema(databaseID: "db-1234", token: "secret_test_token")

        guard let requestURL = CapturingURLProtocol.lastRequest?.url else {
            throw SmokeTestFailure(description: "expected fetchDatabaseSchema to issue a request")
        }

        try expect(
            requestURL.absoluteString == "https://api.notion.com/v1/databases/db-1234",
            "database schema requests should append the endpoint path without adding a query string"
        )
    }
}

final class CapturingURLProtocol: URLProtocol {
    nonisolated(unsafe) static var lastRequest: URLRequest?
    nonisolated(unsafe) static var responseBody = #"{"results":[]}"#.data(using: .utf8)!

    static func reset() {
        lastRequest = nil
        responseBody = #"{"results":[]}"#.data(using: .utf8)!
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lastRequest = request

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseBody)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
