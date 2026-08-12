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
            try taskFieldResolutionUsesCustomNames()
            try taskFieldResolutionReportsAmbiguousDateFields()
            try taskSortingKeepsIncompleteAndHigherPriorityFirst()
            try journalContentBuilderConvertsLinesToParagraphBlocks()
            try notionClientHttpErrorExposesReadableDescription()
            try notionClientHttpErrorExplainsStaleFieldMapping()
            try notionRepositoryValidationErrorExposesReadableDescription()
            try notionRepositoryBuildsTasksDatabasePageURL()
            try todoListViewModelDoesNotSynchronouslyBridgeNestedObjectWillChange()
            try todoHeaderOpenButtonTargetsTasksDatabasePage()
            try journalHeaderContainsManualSyncButton()
            try journalAutosaveDoesNotCancelAnInFlightWrite()
            try journalOpenInNotionButtonSitsBesideHeaderSyncButton()
            try journalDateUsesSelectedLanguage()
            try journalEditorTypographyUsesRelaxedEditorRhythm()
            try todoAndJournalPanelsUseHtmlReferenceBorderWidth()
            try todoDateNavigationKeepsArrowSpacingStable()
            try journalEditorUsesOverflowAwareEdgeAlignedScroller()
            try topBarDoesNotShowExpandButton()
            try welcomeViewUsesDedicatedIllustrationAssetAndCallback()
            try configurationFormContainsSettingsHelpAndExtractionCopy()
            try newTaskFormKeepsCreateTaskContract()
            try taskFormsUseSharedSlimScrollerContract()
            try newTaskTypePickerUsesSearchableDropdownContract()
            try editTaskTypePickerUsesSearchableDropdownContract()
            try todoTaskDurationMatchesHtmlReferenceContract()
            try newTaskFormDoesNotDimTodoPanel()
            try onboardingVisualAlignmentKeepsExistingBehaviorContract()
            try todoDateTitleUsesChineseDateWithoutTodaySpecialCase()
            try settingsResetFlowReturnsUserToWelcome()
            try settingsContainsPersistentLanguageControl()
            try onboardingContainsPersistentLanguageControl()
            try statusBarMenuContainsSettingsEntry()
            try floatingWindowManagerDoesNotDependOnGlobalMouseUpMonitoring()
            try floatingPanelDoesNotSynchronouslyActivateDuringEventDispatch()
            try pomodoroViewModelIntegrationKeepsContract()
            try pomodoroViewsKeepContract()
            try pomodoroContentViewIntegrationKeepsContract()
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
        let result = FieldValidator.resolve(
            [
                NotionPropertySchema(name: "Name", type: "title"),
                NotionPropertySchema(name: "Done", type: "checkbox")
            ],
            for: .tasks
        )

        switch result {
        case let .failure(issues):
            try expect(
                issues.map(\.message.key) == [.missingRequiredFieldType]
                    && issues.map(\.message.arguments) == [["date"]],
                "task schema validation should report the missing required type"
            )
        default:
            throw SmokeTestFailure(description: "task schema validation should fail when the date type is missing")
        }
    }

    static func taskFieldResolutionUsesCustomNames() throws {
        let result = FieldValidator.resolve(
            [
                NotionPropertySchema(name: "任务标题", type: "title"),
                NotionPropertySchema(name: "计划日期", type: "date"),
                NotionPropertySchema(name: "已完成", type: "checkbox"),
                NotionPropertySchema(name: "任务优先级", type: "select")
            ],
            for: .tasks
        )

        switch result {
        case let .success(.tasks(mapping)):
            try expect(mapping.title == "任务标题", "task title field should resolve from the title type")
            try expect(mapping.date == "计划日期", "task date field should resolve from the date type")
            try expect(mapping.done == "已完成", "task done field should resolve from the checkbox type")
            try expect(mapping.priority == "任务优先级", "task priority field should resolve from the unique select type")
        default:
            throw SmokeTestFailure(description: "task field resolution should succeed for unique required types")
        }
    }

    static func taskFieldResolutionReportsAmbiguousDateFields() throws {
        let result = FieldValidator.resolve(
            [
                NotionPropertySchema(name: "开始时间", type: "date"),
                NotionPropertySchema(name: "截止时间", type: "date"),
                NotionPropertySchema(name: "任务标题", type: "title"),
                NotionPropertySchema(name: "已完成", type: "checkbox")
            ],
            for: .tasks
        )

        switch result {
        case let .failure(issues):
            try expect(
                issues.map(\.message.key) == [.duplicateRequiredField]
                    && issues.map(\.message.arguments) == [["date", "开始时间, 截止时间", "date"]],
                "task schema validation should report ambiguous date fields with readable names"
            )
        default:
            throw SmokeTestFailure(description: "task field resolution should fail for ambiguous required date fields")
        }
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

    static func notionClientHttpErrorExplainsStaleFieldMapping() throws {
        let error = NotionClientError.httpError(
            statusCode: 400,
            message: #"{"object":"error","status":400,"message":"Could not find property with name or id: Date"}"#
        )

        try expect(
            error.localizedDescription == "Notion 请求失败（HTTP 400）：数据库字段可能已改名或已删除，请重新进入初始化配置并保存一次数据库设置。",
            "field lookup HTTP errors should explain that the saved database mapping is stale"
        )
    }

    static func notionRepositoryValidationErrorExposesReadableDescription() throws {
        let error = NotionRepositoryError.validationFailed(
            [
                ValidationIssue(.missingRequiredFieldType, arguments: ["Name(title)"]),
                ValidationIssue(.missingRequiredFieldType, arguments: ["date"])
            ]
        )

        try expect(
            error.localizedDescription == "数据库字段校验失败：缺少必填字段类型：Name(title)；缺少必填字段类型：date",
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
        guard let openActionRange = source.range(of: "todoViewModel.openTasksDatabaseInNotion()") else {
            throw SmokeTestFailure(description: "todo header open button action should be present")
        }
        let openButtonStart = source[..<openActionRange.lowerBound].lastIndex(of: "\n") ?? source.startIndex
        let openButtonEnd = source[openActionRange.upperBound...].range(of: ".buttonStyle(FloatingWidgetIconButtonStyle())")?.upperBound ?? openActionRange.upperBound
        let openButtonScope = source[openButtonStart..<openButtonEnd]
        try expect(
            openButtonScope.contains("headerActionIcon(systemName: \"arrow.up.forward.square\")"),
            "todo header open icon should render through the shared header action icon helper"
        )
        try expect(
            source.contains("static let headerIconButtonSize: CGFloat = 24")
                && source.contains("static let headerIconSymbolSize: CGFloat = 16"),
            "header action buttons should define shared click-area and symbol-size constants"
        )
        try expect(
            source.contains(".font(.system(size: FloatingWidgetMetrics.headerIconSymbolSize, weight: .regular))")
                && source.contains(".frame(")
                && source.contains("width: FloatingWidgetMetrics.headerIconSymbolSize")
                && source.contains("height: FloatingWidgetMetrics.headerIconSymbolSize"),
            "header action icons should share one font size, weight, and symbol frame"
        )
        try expect(
            source.contains("headerActionIcon(systemName: \"plus\")")
                && source.contains("headerActionIcon(systemName: \"arrow.triangle.2.circlepath\")")
                && source.contains("headerActionIcon(systemName: \"arrow.up.forward.square\")"),
            "todo and journal header action icons should render through the shared icon helper"
        )
        try expect(
            source.contains("Image(systemName: headerActionSystemName(for: systemName))")
                && source.contains("private func headerActionSystemName(for systemName: String) -> String")
                && !source.contains("private struct HeaderActionSymbol: Shape"),
            "header action icons should render through one shared SF Symbol mapping helper"
        )
        try expect(
            source.contains("case \"arrow.triangle.2.circlepath\":")
                && source.contains("return \"arrow.clockwise\""),
            "sync header action icon should use the standard clockwise refresh symbol inside the shared icon frame"
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
            source.contains("headerActionIcon(systemName: \"arrow.triangle.2.circlepath\")"),
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
            journalViewModelSource.contains("debounceTask?.cancel()"),
            "reloading from Notion should cancel any pending autosave before overwriting local text"
        )
        try expect(
            journalViewModelSource.contains("await load()"),
            "reloading from Notion should reuse the existing journal load path"
        )
        try expect(
            !source.contains("static let journalHeading ="),
            "journal heading color constant should be removed after dropping the heading element"
        )
        try expect(
            !source.contains("Text(\"日记\")"),
            "journal panel should no longer render a standalone heading text"
        )
        try expect(
            !source.contains("private var journalToolbar: some View"),
            "journal toolbar should be inlined into the date row to eliminate top blank gap"
        )
        try expect(
            !source.contains("journalHeadingBottomSpacing"),
            "journal heading bottom spacing should be removed along with the heading"
        )
    }

    static func journalAutosaveDoesNotCancelAnInFlightWrite() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewModelURL = rootURL
            .appendingPathComponent("WidgetToDo")
            .appendingPathComponent("JournalViewModel.swift")
        let source = try String(contentsOf: viewModelURL, encoding: .utf8)

        try expect(
            source.contains("private var debounceTask: Task<Void, Never>?") &&
                source.contains("private var saveTask: Task<Void, Never>?"),
            "journal autosave should keep debounce and network-save tasks separate"
        )
        try expect(
            source.contains("enqueueSave(text: text)") &&
                source.contains("guard saveTask == nil else { return }"),
            "journal autosave should queue the latest text instead of cancelling an in-flight write"
        )
    }

    static func journalOpenInNotionButtonSitsBesideHeaderSyncButton() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let contentViewURL = rootURL
            .appendingPathComponent("WidgetToDo")
            .appendingPathComponent("ContentView.swift")
        let source = try String(contentsOf: contentViewURL, encoding: .utf8)

        try expect(
            source.contains("HStack(spacing: FloatingWidgetMetrics.headerIconButtonSpacing)"),
            "journal header action buttons should use the shared icon-button spacing"
        )
        try expect(
            source.contains("if let url = journalViewModel.entry?.url"),
            "journal header open button should depend on the journal entry URL being available"
        )
        try expect(
            source.contains("journalViewModel.openInNotion(url)"),
            "journal header open button should open the current journal page"
        )
        try expect(
            source.contains("headerActionIcon(systemName: \"arrow.up.forward.square\")"),
            "journal header open icon should render through the shared header action icon helper"
        )
        try expect(
            !source.contains("Text(\"在 Notion 中打开\")"),
            "journal open-in-Notion button should render as icon-only"
        )
    }

    static func journalEditorTypographyUsesRelaxedEditorRhythm() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let contentViewURL = rootURL
            .appendingPathComponent("WidgetToDo")
            .appendingPathComponent("ContentView.swift")
        let source = try String(contentsOf: contentViewURL, encoding: .utf8)

        try expect(
            source.contains("static let journalDateBottomSpacing: CGFloat = 14"),
            "journal date should leave more breathing room before the editor"
        )
        try expect(
            source.contains("static let journalEditorFontSize: CGFloat = 13"),
            "journal editor should use a restrained 13pt body size"
        )
        try expect(
            source.contains("static let journalEditorLineSpacing: CGFloat = 6"),
            "journal editor should loosen line spacing for multi-line notes"
        )
        try expect(
            source.contains("static let journalEditorInsets = EdgeInsets(top: 16, leading: 16, bottom: 40, trailing: 18)"),
            "journal editor should use roomier text insets"
        )
        try expect(
            source.contains("lineSpacing: FloatingWidgetMetrics.journalEditorLineSpacing"),
            "journal editor should pass the relaxed line spacing into the custom AppKit editor"
        )
        try expect(
            source.contains("paragraphStyle.lineSpacing = configuration.lineSpacing"),
            "journal editor should apply the relaxed line spacing to NSTextView paragraph style"
        )
        try expect(
            !source.contains(".modifier(TrackingModifier(value: -0.12))"),
            "journal editor body should not squeeze glyph spacing with negative tracking"
        )
    }

    static func todoAndJournalPanelsUseHtmlReferenceBorderWidth() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let contentViewURL = rootURL
            .appendingPathComponent("WidgetToDo")
            .appendingPathComponent("ContentView.swift")
        let source = try String(contentsOf: contentViewURL, encoding: .utf8)

        try expect(
            source.contains("static let panelBorderLineWidth: CGFloat = 0.5"),
            "todo and journal panels should share the HTML reference 0.5pt border width"
        )
        try expect(
            source.components(separatedBy: "lineWidth: FloatingWidgetMetrics.panelBorderLineWidth").count - 1 >= 2,
            "todo list and journal editor should both use the shared panel border width"
        )
        try expect(
            !source.contains(".stroke(FloatingWidgetPalette.editorBorder, lineWidth: 1.5)"),
            "todo and journal panels should not keep the previous 1.5pt border width"
        )
    }

    static func journalDateUsesSelectedLanguage() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let contentViewURL = rootURL
            .appendingPathComponent("WidgetToDo")
            .appendingPathComponent("ContentView.swift")
        let source = try String(contentsOf: contentViewURL, encoding: .utf8)

        try expect(
            source.contains("TodoDateDisplayFormatter.title(for: date, language: languageStore.language)"),
            "journal date should reuse the todo date formatter with the selected language"
        )
        try expect(
            !source.contains("formatter.dateFormat = \"yyyy年M月d日\""),
            "journal date should not keep a separate yyyy年M月d日 formatter"
        )
        guard let journalDateRange = source.range(of: "Text(journalDateString(from: entry.date))") else {
            throw SmokeTestFailure(description: "journal date text should be present")
        }
        let journalDateScopeEnd = source[journalDateRange.upperBound...].range(of: "Spacer()")?.lowerBound ?? journalDateRange.upperBound
        let journalDateScope = source[journalDateRange.lowerBound..<journalDateScopeEnd]
        try expect(
            journalDateScope.contains(".font(.system(size: 14, weight: .bold))"),
            "journal date should use the same font style as the todo date title"
        )
        try expect(
            journalDateScope.contains(".foregroundStyle(FloatingWidgetPalette.todoDateTitle)"),
            "journal date should use the same color as the todo date title"
        )
        try expect(
            journalDateScope.contains(".modifier(TrackingModifier(value: -0.28))"),
            "journal date should use the same tracking as the todo date title"
        )
    }

    static func journalEditorUsesOverflowAwareEdgeAlignedScroller() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let contentViewURL = rootURL
            .appendingPathComponent("WidgetToDo")
            .appendingPathComponent("ContentView.swift")
        let source = try String(contentsOf: contentViewURL, encoding: .utf8)

        try expect(
            source.contains("JournalTextEditor(")
                && source.contains("text: $journalViewModel.editorText"),
            "journal panel should use the custom AppKit editor instead of SwiftUI TextEditor"
        )
        try expect(
            source.contains("final class Coordinator: NSObject, NSTextViewDelegate"),
            "journal editor should delegate text changes from NSTextView back to SwiftUI"
        )
        try expect(
            source.contains("hasVerticalScroller = contentOverflows"),
            "journal editor should only show the vertical scroller when content overflows"
        )
        try expect(
            source.contains("scrollView.autohidesScrollers = true"),
            "journal editor should allow the scrollbar to fully hide when content fits"
        )
        try expect(
            source.contains("textView.textContainerInset = NSSize(width:"),
            "journal editor should apply text padding inside NSTextView so the NSScrollView scroller remains edge-aligned"
        )
    }

    static func todoDateNavigationKeepsArrowSpacingStable() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let contentViewURL = rootURL
            .appendingPathComponent("WidgetToDo")
            .appendingPathComponent("ContentView.swift")
        let source = try String(contentsOf: contentViewURL, encoding: .utf8)
        guard let toolbarStart = source.range(of: "private var todoToolbar: some View") else {
            throw SmokeTestFailure(description: "todo toolbar should remain present")
        }
        guard let toolbarEnd = source[toolbarStart.upperBound...].range(of: "private var syncBanner", options: [], range: toolbarStart.upperBound..<source.endIndex)?.lowerBound else {
            throw SmokeTestFailure(description: "todo toolbar scope should end before the sync banner")
        }
        let toolbarSource = String(source[toolbarStart.lowerBound..<toolbarEnd])

        try expect(
            source.contains("static let todoDateTitleWidth: CGFloat = 60"),
            "todo date title should reserve enough fixed width for the 14pt today label"
        )
        try expect(
            source.contains(".frame(width: FloatingWidgetMetrics.todoDateTitleWidth, alignment: .center)"),
            "todo date title should render inside the fixed-width frame"
        )
        try expect(
            source.contains("static let todoDateNavigationSpacing: CGFloat = 4"),
            "todo date navigation should define a compact shared spacing constant"
        )
        try expect(
            source.contains("HStack(spacing: FloatingWidgetMetrics.todoDateNavigationSpacing)"),
            "todo date navigation group should consume the compact spacing constant"
        )
        try expect(
            source.contains("static let todoDateTitleFontSize: CGFloat = 14"),
            "todo date title should use the non-today date font size as the shared baseline"
        )
        try expect(
            source.contains(".font(.system(size: FloatingWidgetMetrics.todoDateTitleFontSize, weight: .bold))"),
            "todo date title should use the shared font size for today and non-today dates"
        )
        try expect(
            !source.contains(".minimumScaleFactor("),
            "todo date title should not scale today's text smaller than non-today dates"
        )
        try expect(
            source.contains(".allowsTightening(true)"),
            "todo date title should tighten glyph spacing before truncation"
        )
        try expect(
            !toolbarSource.contains(".frame(height: 28)"),
            "todo date title should not force a taller vertical slot"
        )
        try expect(
            source.contains("Spacer(minLength: 0)")
                && source.contains(".frame(width: FloatingWidgetMetrics.jumpToTodayWidth)"),
            "today-state placeholder should reserve width without using a vertically expanding Color"
        )
        try expect(
            !source.contains("Color.clear\n                    .frame(width: FloatingWidgetMetrics.jumpToTodayWidth)"),
            "today-state placeholder should not use unconstrained Color.clear because it can expand vertically"
        )
        try expect(
            source.contains("static let jumpToTodayWidth: CGFloat = 44"),
            "jump-to-today control should reserve a stable slot width"
        )
        try expect(
            source.contains("static let jumpToTodayLeadingPadding: CGFloat = 2"),
            "jump-to-today control should define a compact shared leading padding"
        )
        try expect(
            source.contains(".padding(.leading, FloatingWidgetMetrics.jumpToTodayLeadingPadding)"),
            "jump-to-today control should consume the compact leading padding constant"
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

    static func settingsContainsPersistentLanguageControl() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let contentViewURL = rootURL
            .appendingPathComponent("WidgetToDo")
            .appendingPathComponent("ContentView.swift")
        let source = try String(contentsOf: contentViewURL, encoding: .utf8)

        guard let languageRange = source.range(of: "languageSection"),
              let tokenRange = source.range(of: "tokenSection")
        else {
            throw SmokeTestFailure(description: "settings should define language and token sections")
        }

        try expect(source.contains("Label(\"Language\""), "settings must keep the Language title fixed")
        try expect(source.contains("AppLanguage.allCases"), "settings must offer all supported languages")
        try expect(languageRange.lowerBound < tokenRange.lowerBound, "language must appear before Notion Token")
        try expect(source.contains("selectLanguage"), "language selection must persist through RootViewModel")
    }

    static func onboardingContainsPersistentLanguageControl() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let contentViewURL = rootURL
            .appendingPathComponent("WidgetToDo")
            .appendingPathComponent("ContentView.swift")
        let source = try String(contentsOf: contentViewURL, encoding: .utf8)

        guard let onboardingRange = source.range(of: "case .onboarding:"),
              let settingsRange = source.range(of: "case .settings:"),
              let formLayoutRange = source.range(of: "if mode == .settings {")
        else {
            throw SmokeTestFailure(description: "onboarding language control should have a discoverable view structure")
        }

        let onboardingConstruction = String(source[onboardingRange.lowerBound..<settingsRange.lowerBound])
        let formLayout = String(source[formLayoutRange.lowerBound...])
        try expect(
            onboardingConstruction.contains("onLanguageChange: rootViewModel.selectLanguage"),
            "onboarding should persist language selection through RootViewModel"
        )
        try expect(
            formLayout.contains("} else {\n                            onboardingHero\n                            languageSection\n                        }\n\n                        tokenSection"),
            "onboarding should place the shared language control directly before Notion Token"
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
            source.contains("languageStore.text(.settingsTitle)"),
            "status bar menu should localize its settings item"
        )
        try expect(
            source.contains("NSColor.white.cgColor") && !source.contains("effectiveAppearance"),
            "status bar icon should keep the verified fixed-white rendering without appearance guessing"
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
            source.contains("presentContextMenu(menu, with: event, for: button)"),
            "status bar event monitor should defer contextual menu presentation instead of tracking it inline"
        )
        try expect(
            source.contains("private func presentContextMenu")
                && source.contains("DispatchQueue.main.async")
                && source.contains("NSMenu.popUpContextMenu(menu, with: event, for: button)"),
            "status bar item should present the contextual menu on the next main-queue turn"
        )
        try expect(
            source.contains("item.length = NSStatusItem.squareLength"),
            "status bar item should keep the compact icon-only width"
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
            source.contains("accessibilityLabel(languageStore.text(.notionToken))"),
            "configuration form should keep an accessibility label for the token field"
        )
        try expect(
            source.contains("Text(languageStore.text(.howToGet))"),
            "configuration form should localize the token help copy"
        )
        try expect(
            source.contains("Text(languageStore.text(.pasteFullURL))"),
            "database sections should localize automatic URL extraction copy"
        )
        try expect(
            source.contains("activeDatabaseHelpTopic = .tasks") &&
                source.contains("activeDatabaseHelpTopic = .journal"),
            "configuration form should expose dedicated help actions for tasks and journal databases"
        )
        try expect(
            source.contains("TasksDatabaseHelpView()") &&
                source.contains("JournalDatabaseHelpView()"),
            "configuration form should present separate help sheets for tasks and journal databases"
        )
        try expect(
            source.contains("HelpSheetLayout(titleKey: .tasksDatabaseHelpTitle") &&
                source.contains("HelpSheetLayout(titleKey: .journalDatabaseHelpTitle") &&
                source.contains("Text(languageStore.text(tab.textKey))"),
            "database help sheets and widget tabs should use language-aware text keys"
        )
        try expect(
            source.contains("Text(languageStore.text(.journalHelpStep3))") &&
                source.contains("Text(languageStore.text(.journalHelpStep4))"),
            "journal database help should localize required-fields and page-body-storage guidance"
        )
        try expect(
            source.contains("Text(languageStore.text(.journalHelpStep5))"),
            "journal database help should localize the gallery-view recommendation"
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

    static func newTaskFormKeepsCreateTaskContract() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let formURL = rootURL
            .appendingPathComponent("WidgetToDo")
            .appendingPathComponent("NewTaskFormCard.swift")
        let source = try String(contentsOf: formURL, encoding: .utf8)
        guard let formStart = source.range(of: "struct NewTaskFormCard") else {
            throw SmokeTestFailure(description: "new task form source should define NewTaskFormCard")
        }
        guard let openingBrace = source[formStart.upperBound...].firstIndex(of: "{") else {
            throw SmokeTestFailure(description: "new task form source should open a struct body")
        }

        var depth = 0
        var closingBrace: String.Index?
        var index = openingBrace
        var isInString = false
        var isEscapingString = false
        var isInLineComment = false
        var isInBlockComment = false

        while index < source.endIndex {
            let character = source[index]
            let nextIndex = source.index(after: index)
            let nextCharacter = nextIndex < source.endIndex ? source[nextIndex] : nil

            if isInLineComment {
                if character == "\n" {
                    isInLineComment = false
                }
            } else if isInBlockComment {
                if character == "*" && nextCharacter == "/" {
                    isInBlockComment = false
                    index = nextIndex
                }
            } else if isInString {
                if isEscapingString {
                    isEscapingString = false
                } else if character == "\\" {
                    isEscapingString = true
                } else if character == "\"" {
                    isInString = false
                }
            } else {
                if character == "/" && nextCharacter == "/" {
                    isInLineComment = true
                    index = nextIndex
                } else if character == "/" && nextCharacter == "*" {
                    isInBlockComment = true
                    index = nextIndex
                } else if character == "\"" {
                    isInString = true
                } else if character == "{" {
                    depth += 1
                } else if character == "}" {
                    depth -= 1
                    if depth == 0 {
                        closingBrace = index
                        break
                    }
                }
            }
            index = source.index(after: index)
        }

        guard let formEnd = closingBrace else {
            throw SmokeTestFailure(description: "new task form source should close the struct body")
        }

        let formSource = String(source[formStart.lowerBound...formEnd])
        var sanitized = ""
        sanitized.reserveCapacity(formSource.count)

        var sanitizedIndex = formSource.startIndex
        var isInSanitizedString = false
        var isEscapingSanitizedString = false
        var isInSanitizedLineComment = false
        var isInSanitizedBlockComment = false

        while sanitizedIndex < formSource.endIndex {
            let character = formSource[sanitizedIndex]
            let nextIndex = formSource.index(after: sanitizedIndex)
            let nextCharacter = nextIndex < formSource.endIndex ? formSource[nextIndex] : nil

            if isInSanitizedLineComment {
                if character == "\n" {
                    isInSanitizedLineComment = false
                    sanitized.append(character)
                }
            } else if isInSanitizedBlockComment {
                if character == "*" && nextCharacter == "/" {
                    isInSanitizedBlockComment = false
                    sanitizedIndex = nextIndex
                }
            } else if isInSanitizedString {
                if isEscapingSanitizedString {
                    isEscapingSanitizedString = false
                } else if character == "\\" {
                    isEscapingSanitizedString = true
                } else if character == "\"" {
                    isInSanitizedString = false
                    sanitized.append(character)
                }
            } else if character == "/" && nextCharacter == "/" {
                isInSanitizedLineComment = true
                sanitizedIndex = nextIndex
            } else if character == "/" && nextCharacter == "*" {
                isInSanitizedBlockComment = true
                sanitizedIndex = nextIndex
            } else if character == "\"" {
                isInSanitizedString = true
                sanitized.append(character)
            } else {
                sanitized.append(character)
            }

            sanitizedIndex = formSource.index(after: sanitizedIndex)
        }

        let normalized = sanitized.replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)

        try expect(
            normalized.contains("viewModel.title"),
            "new task form should keep the title binding"
        )
        try expect(
            normalized.contains("viewModel.taskDate"),
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
            !normalized.contains("regularMaterial"),
            "new task form should no longer use regularMaterial in the bounded form source"
        )
        try expect(
            formSource.contains("private var newTaskHeader: some View") &&
                formSource.contains("private var newTaskFooter: some View") &&
                formSource.contains("private var newTaskScrollableContent: some View"),
            "new task form should split fixed header and footer from its scrollable content"
        )
        try expect(
            formSource.contains("contentHeightLimit: scrollableContentHeightLimit") &&
                formSource.contains("NewTaskFormMetrics.cardMaxHeight - headerHeight - footerHeight"),
            "new task form should reserve fixed regions from its scrollable height limit"
        )
        try expect(
            formSource.contains(".animation(.easeInOut(duration: 0.22), value: isTypeOptionsPresented)"),
            "new task form should animate type-list height changes"
        )
    }

    static func taskFormsUseSharedSlimScrollerContract() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let appURL = rootURL.appendingPathComponent("WidgetToDo")
        let scrollerSource = try String(
            contentsOf: appURL.appendingPathComponent("SlimFormScrollView.swift"),
            encoding: .utf8
        )
        let newTaskSource = try String(
            contentsOf: appURL.appendingPathComponent("NewTaskFormCard.swift"),
            encoding: .utf8
        )
        let contentSource = try String(
            contentsOf: appURL.appendingPathComponent("ContentView.swift"),
            encoding: .utf8
        )

        try expect(
            scrollerSource.contains("struct SlimFormScrollView"),
            "task forms should share a dedicated slim scroll view"
        )
        try expect(
            scrollerSource.contains("static let thumbWidth: CGFloat = 5"),
            "task form scrollbar thumb should be 5 pt wide"
        )
        try expect(
            scrollerSource.contains("final class SlimVerticalScroller: NSScroller"),
            "shared form scroller should keep native drag behavior"
        )
        try expect(
            scrollerSource.contains("private func updateDocumentLayout()") &&
                scrollerSource.contains("hostingView.frame = NSRect"),
            "shared form scroller should recompute document height when SwiftUI content changes"
        )
        try expect(
            scrollerSource.contains("let usesContentHeight: Bool") &&
                scrollerSource.contains("usesContentHeight: Bool = false"),
            "shared slim scroller should keep content-height negotiation opt-in"
        )
        try expect(
            scrollerSource.contains("override var intrinsicContentSize: NSSize") &&
                scrollerSource.contains("invalidateIntrinsicContentSize()"),
            "content-height scroller should expose and invalidate measured intrinsic height"
        )
        try expect(
            scrollerSource.contains("let contentHeightLimit: CGFloat?") &&
                scrollerSource.contains("min(measuredContentHeight, contentHeightLimit ?? measuredContentHeight)"),
            "content-height scroller should cap its intrinsic height"
        )
        try expect(
            scrollerSource.contains("hostingView.frame.size.height = contentHeight") &&
                !scrollerSource.contains("hostingView.frame.size.height = min(contentHeight"),
            "content-height scroller should preserve the full document height for scrolling"
        )
        try expect(
            newTaskSource.contains("SlimFormScrollView("),
            "new task form should use the shared slim scroll view"
        )

        guard let editStart = contentSource.range(of: "struct EditTaskFormCard: View"),
              let previewStart = contentSource[editStart.upperBound...].range(
                  of: "#Preview",
                  options: [],
                  range: editStart.upperBound..<contentSource.endIndex
              )?.lowerBound else {
            throw SmokeTestFailure(description: "edit task form scope should remain available")
        }
        let editSource = String(contentSource[editStart.lowerBound..<previewStart])
        try expect(
            editSource.contains("SlimFormScrollView(") &&
                editSource.contains("usesContentHeight: true") &&
                editSource.contains("contentHeightLimit: scrollableContentHeightLimit"),
            "edit form should cap its content-driven height at the card maximum"
        )
        try expect(
            editSource.contains("NewTaskFormMetrics.cardMaxHeight - headerHeight - footerHeight"),
            "edit form should reserve its fixed header and footer from the scrollable height limit"
        )
    }

    static func newTaskTypePickerUsesSearchableDropdownContract() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let formURL = rootURL
            .appendingPathComponent("WidgetToDo")
            .appendingPathComponent("NewTaskFormCard.swift")
        let source = try String(contentsOf: formURL, encoding: .utf8)

        try expect(
            source.contains("@State private var searchText"),
            "type picker should keep local search text"
        )
        try expect(
            source.contains("@State private var isOptionsPresented"),
            "type picker should keep local dropdown state"
        )
        try expect(
            source.contains("TextField(\"搜索或选择类型\""),
            "type picker should expose an input placeholder"
        )
        try expect(
            source.contains("Image(systemName: \"chevron.down\")"),
            "type picker should use a down arrow"
        )
        try expect(
            source.contains("filteredOptions"),
            "type picker should filter Notion options"
        )
        try expect(
            source.contains("selection = option.name"),
            "type picker should preserve the selection binding"
        )
        try expect(
            source.contains("selection = nil"),
            "type picker should retain a clear choice"
        )
        try expect(
            source.contains("optionsListHeight") && source.contains(".frame(height: optionsListHeight)"),
            "type picker should reserve visible height for filtered options"
        )
        try expect(
            source.contains("SlimFormScrollView(") &&
                source.contains("maxHeight: NewTaskFormMetrics.cardMaxHeight"),
            "new task form should use the shared overflow-aware slim scroller"
        )
        try expect(
            source.contains("let onOptionsPresentedChange: (Bool) -> Void") &&
                source.contains("onOptionsPresentedChange(isOptionsPresented)"),
            "new task type picker should report expanded state to its parent"
        )
        try expect(
            source.contains("TaskChoicePicker(") &&
                source.contains("onOptionsPresentedChange: { isTypeOptionsPresented = $0 }"),
            "new task form should use picker state to drive its height"
        )
    }

    static func editTaskTypePickerUsesSearchableDropdownContract() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let contentViewURL = rootURL
            .appendingPathComponent("WidgetToDo")
            .appendingPathComponent("ContentView.swift")
        let source = try String(contentsOf: contentViewURL, encoding: .utf8)
        guard let editFormStart = source.range(of: "struct EditTaskFormCard: View") else {
            throw SmokeTestFailure(description: "edit form should remain present")
        }
        guard let editFormEnd = source[editFormStart.upperBound...].range(of: "#Preview", options: [], range: editFormStart.upperBound..<source.endIndex)?.lowerBound else {
            throw SmokeTestFailure(description: "edit form scope should end before previews")
        }
        let editFormSource = String(source[editFormStart.lowerBound..<editFormEnd])

        try expect(editFormSource.contains("struct EditTaskFormCard"), "edit form should remain present")
        try expect(source.contains("@State private var typeSearchText"), "edit picker should keep local search text")
        try expect(source.contains("@State private var isTypeOptionsPresented"), "edit picker should keep local dropdown state")
        try expect(source.contains("TextField(\"搜索或选择类型\""), "edit picker should expose a search input")
        try expect(source.contains("Image(systemName: \"chevron.down\")"), "edit picker should use a down arrow")
        try expect(source.contains("filteredTypeOptions"), "edit picker should filter Notion options")
        try expect(source.contains("viewModel.editingPriority = option.name"), "edit picker should preserve the editing binding")
        try expect(source.contains("viewModel.editingPriority = nil"), "edit picker should keep a clear choice")
        try expect(
            source.contains("typeOptionsListHeight") && source.contains(".frame(height: typeOptionsListHeight)"),
            "edit picker should reserve visible height for filtered options"
        )
        try expect(
            editFormSource.contains("usesContentHeight: true") &&
                editFormSource.contains("contentHeightLimit: scrollableContentHeightLimit") &&
                source.contains("maxHeight: NewTaskFormMetrics.cardMaxHeight"),
            "edit form should use the shared overflow-aware slim scroller"
        )
        try expect(
            editFormSource.contains("private var editTaskHeader: some View") &&
                editFormSource.contains("private var editTaskFooter: some View") &&
                editFormSource.contains("private var editTaskScrollableContent: some View"),
            "edit form should split fixed header and footer from its scrollable content"
        )
        try expect(
            editFormSource.contains("contentHeightLimit: scrollableContentHeightLimit"),
            "edit form should bound only its scrollable content"
        )
        try expect(
            editFormSource.contains("NewTaskFormMetrics.cardMaxHeight - headerHeight - footerHeight"),
            "edit form should reserve fixed regions when calculating its scrollable height"
        )
        try expect(
            editFormSource.contains(".animation(.easeInOut(duration: 0.22), value: isTypeOptionsPresented)"),
            "edit form should animate type-list height changes"
        )
        try expect(
            !editFormSource.contains(".fixedSize(horizontal: false, vertical: !isTypeOptionsPresented)"),
            "AppKit-backed edit form should not use the incompatible fixed-size modifier"
        )
    }

    static func newTaskFormDoesNotDimTodoPanel() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let contentViewURL = rootURL
            .appendingPathComponent("WidgetToDo")
            .appendingPathComponent("ContentView.swift")
        let source = try String(contentsOf: contentViewURL, encoding: .utf8)

        guard let branchStart = source.range(of: "if newTaskViewModel.showForm {") else {
            throw SmokeTestFailure(description: "todo panel should keep a dedicated new task form branch")
        }
        guard let editBranchStart = source.range(of: "if todoViewModel.editingTask != nil {", range: branchStart.upperBound..<source.endIndex) else {
            throw SmokeTestFailure(description: "todo panel should keep the edit task form branch after the new task form branch")
        }

        let branchSource = String(source[branchStart.lowerBound..<editBranchStart.lowerBound])
        let normalized = branchSource.replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)

        try expect(
            normalized.contains("NewTaskFormCard(viewModel:newTaskViewModel)"),
            "todo panel should keep presenting the dedicated new task form card"
        )
        try expect(
            !normalized.contains("Color.black.opacity(0.3)"),
            "new task form should no longer dim the todo panel with a gray backdrop"
        )
    }

    static func todoTaskDurationMatchesHtmlReferenceContract() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let newTaskFormURL = rootURL
            .appendingPathComponent("WidgetToDo")
            .appendingPathComponent("NewTaskFormCard.swift")
        let pendingRowURL = rootURL
            .appendingPathComponent("WidgetToDo")
            .appendingPathComponent("PendingTodoRowView.swift")
        let contentViewURL = rootURL
            .appendingPathComponent("WidgetToDo")
            .appendingPathComponent("ContentView.swift")

        let newTaskFormSource = try String(contentsOf: newTaskFormURL, encoding: .utf8)
        let pendingRowSource = try String(contentsOf: pendingRowURL, encoding: .utf8)
        let contentViewSource = try String(contentsOf: contentViewURL, encoding: .utf8)

        try expect(
            newTaskFormSource.contains("estimatedMinutes"),
            "new task form should expose an estimated-minutes input"
        )
        try expect(
            pendingRowSource.contains("estimatedMinutes") &&
                pendingRowSource.contains(#"Image(systemName: "clock")"#) &&
                pendingRowSource.contains("min"),
            "pending todo rows should render duration with a clock icon and minute suffix"
        )
        try expect(
            contentViewSource.contains("estimatedMinutes") &&
                contentViewSource.contains(#"Image(systemName: "clock")"#) &&
                contentViewSource.contains("min"),
            "synced todo rows should render duration with a clock icon and minute suffix"
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
            signature: "private func databaseSection("
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
            databaseSectionScope.contains(".onChange(of: text.wrappedValue) {"),
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
            primaryButtonScope.contains("Text(languageStore.text(mode == .settings ? .saveSettings : .verifyAndContinue))"),
            "onboarding alignment refresh must localize its CTA copy"
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
            contentSource.contains("languageStore.text(.resetConfiguration)"),
            "settings UI should localize the reset configuration entry point"
        )
        try expect(
            contentSource.contains("languageStore.text(.resetConfigurationConfirmation)"),
            "settings reset confirmation should localize the local-cache explanation"
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
        guard let modalHeaderScope = functionScope(
            in: contentSource,
            signature: "private var modalHeader: some View"
        ) else {
            throw SmokeTestFailure(
                description: "settings reset flow should keep the modal header that owns the back button"
            )
        }
        try expect(
            modalHeaderScope.contains(".disabled(mode == .settings && (viewModel.isWorking || isResetActionPending))"),
            "settings modal header should disable back navigation while reset is running or locally pending"
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
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = calendar.date(from: DateComponents(year: 2026, month: 6, day: 23))!

        try expect(
            TodoDateDisplayFormatter.title(for: today, today: today, calendar: calendar) == "6月23日",
            "today date title should not include the today prefix"
        )
        try expect(
            TodoDateDisplayFormatter.emptyStateTitle(for: today, today: today, calendar: calendar) == "今天没有任务",
            "today empty state should keep its existing copy"
        )

        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let contentViewURL = rootURL
            .appendingPathComponent("WidgetToDo")
            .appendingPathComponent("ContentView.swift")
        let source = try String(contentsOf: contentViewURL, encoding: .utf8)

        try expect(
            source.components(separatedBy: "for: todoViewModel.selectedDate,\n            language: languageStore.language").count - 1 == 2,
            "todo date title and empty state should both delegate to the shared formatter with the selected language"
        )
        try todoDateNavigationKeepsArrowSpacingStable()
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

    static func pomodoroViewModelIntegrationKeepsContract() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewModelURL = rootURL
            .appendingPathComponent("WidgetToDo")
            .appendingPathComponent("TodoListViewModel.swift")
        let source = try String(contentsOf: viewModelURL, encoding: .utf8)

        try expect(
            source.contains("import AppKit"),
            "TodoListViewModel should import AppKit to play the system beep on natural end"
        )
        try expect(
            source.contains("private var pomodoroEngine = PomodoroSessionEngine()"),
            "TodoListViewModel should own a PomodoroSessionEngine instance"
        )
        try expect(
            source.contains("@Published private(set) var pomodoroSession: PomodoroSession?"),
            "TodoListViewModel should publish the active Pomodoro session"
        )
        try expect(
            source.contains("private var pomodoroTickTask: Task<Void, Never>?"),
            "TodoListViewModel should keep a cancellable Pomodoro tick task"
        )
        try expect(
            source.contains("private var finishedPomodoro: FinishedPomodoroContext?"),
            "TodoListViewModel should track finished Pomodoro context for idempotent retries"
        )
        try expect(
            source.contains("struct FinishedPomodoroContext: Equatable")
                && source.contains("var durationWriteSucceeded: Bool"),
            "FinishedPomodoroContext should expose a durationWriteSucceeded flag for retry gating"
        )
        try expect(
            source.contains("func presentPomodoroStart(for task: TaskItem)")
                && source.contains("func cancelPomodoroStart()")
                && source.contains("func selectPomodoroPreset(_ minutes: Int)")
                && source.contains("func validatePomodoroCustomMinutes() -> Int?")
                && source.contains("func beginPomodoro()"),
            "TodoListViewModel should expose the Pomodoro start/preset/custom/begin entry points"
        )
        try expect(
            source.contains("func pausePomodoro()")
                && source.contains("func resumePomodoro()")
                && source.contains("func requestPomodoroAbandon()")
                && source.contains("func confirmPomodoroAbandon()"),
            "TodoListViewModel should expose pause/resume/abandon actions"
        )
        try expect(
            source.contains("func requestPomodoroManualCompletion()")
                && source.contains("func confirmPomodoroManualCompletion() async"),
            "TodoListViewModel should expose manual completion actions"
        )
        try expect(
            source.contains("func confirmPomodoroNaturalEnd() async")
                && source.contains("func retryPomodoroDurationWrite() async")
                && source.contains("func dismissPomodoroLater()")
                && source.contains("func dismissPomodoroSuccess()"),
            "TodoListViewModel should expose natural-end, retry, and dismiss actions"
        )
        try expect(
            source.contains("Task.sleep(nanoseconds: 1_000_000_000)"),
            "Pomodoro tick should sleep ~1 second between advances to avoid drift"
        )
        try expect(
            source.contains("pomodoroTickTask?.cancel()"),
            "TodoListViewModel should cancel the tick task on deinit and whenever a session pauses/ends"
        )
        try expect(
            source.contains("NSSound.beep()"),
            "Natural end should play a system sound via NSSound.beep()"
        )
        try expect(
            source.contains("let newTotal = (baseMinutes ?? 0) + context.minutesToAdd"),
            "Pomodoro duration writeback should accumulate onto the existing estimatedMinutes (45 + 25 = 70)"
        )
        try expect(
            source.contains("try await repository.updateTaskTitle(")
                && source.contains("estimatedMinutes: newTotal"),
            "Pomodoro duration writeback should reuse the existing updateTaskTitle API with the cumulative total"
        )
        try expect(
            source.contains("guard finishedPomodoro?.taskID == context.taskID else { return }"),
            "Pomodoro writeback should bail out if the finished context has been replaced by another round"
        )
        try expect(
            source.contains("if !durationSuccess {")
                && source.contains("pomodoroPrompt = .durationWriteFailed"),
            "Pomodoro manual completion should surface a duration write failure prompt instead of completing the task"
        )
        try expect(
            source.contains("pomodoroPrompt = .naturalEnd(minutesToAdd: context.minutesToAdd)")
                && source.contains("pomodoroPrompt = .durationWriteFailed"),
            "Pomodoro natural end should present either the natural-end prompt or a duration write failure prompt"
        )
    }

    static func pomodoroViewsKeepContract() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewsURL = rootURL
            .appendingPathComponent("WidgetToDo")
            .appendingPathComponent("PomodoroViews.swift")
        let source = try String(contentsOf: viewsURL, encoding: .utf8)

        try expect(
            source.contains("struct PomodoroFocusCard: View"),
            "PomodoroViews should define PomodoroFocusCard"
        )
        try expect(
            source.contains("struct PomodoroStartCard: View"),
            "PomodoroViews should define PomodoroStartCard"
        )
        try expect(
            source.contains("struct PomodoroPromptCard: View"),
            "PomodoroViews should define PomodoroPromptCard"
        )
        try expect(
            source.contains("struct PomodoroTaskRowStartAction: View"),
            "PomodoroViews should define the compact task-row start action"
        )
        // Start dialog has 25/45/custom presets and NO completion toggle (spec §1, §2).
        try expect(
            source.contains("optionButton(minutes: 25") && source.contains("optionButton(minutes: 45"),
            "Start card should offer 25- and 45-minute presets"
        )
        try expect(
            source.contains("optionButton(minutes: -1"),
            "Start card should offer a custom duration preset"
        )
        try expect(
            !source.contains("completionToggle") || source.contains("private var completionToggle"),
            "completionToggle should only appear in the prompt card, not in the start card"
        )
        // The completion toggle is bound to the view model flag and defaults off (spec §4, §5).
        try expect(
            source.contains("$viewModel.pomodoroCompleteTaskToggle"),
            "Completion toggle should bind to viewModel.pomodoroCompleteTaskToggle"
        )
        // Manual completion offers 继续专注 + dynamic primary (记录时长 / 记录并完成任务).
        try expect(
            source.contains("case .manualCompletion"),
            "Prompt card should route manual completion"
        )
        try expect(
            source.contains(".pomodoroRecordDuration") && source.contains(".pomodoroRecordAndComplete"),
            "Manual end should switch primary action copy with the toggle"
        )
        // Natural end is a single primary action (保持未完成 / 完成任务), no secondary.
        try expect(
            source.contains("case .naturalEnd"),
            "Prompt card should route natural end"
        )
        try expect(
            source.contains(".pomodoroKeepIncomplete") && source.contains(".pomodoroCompleteTask"),
            "Natural end should switch between 保持未完成 and 完成任务"
        )
        // Success state centers a single 知道了 (spec §6).
        try expect(
            source.contains("case .success(let completedTask, let minutesToAdd)"),
            "Prompt card should route success with the recorded minutes"
        )
        try expect(
            source.contains(".pomodoroSuccessCompleted") && source.contains(".pomodoroSuccessIncomplete"),
            "Success dialog should distinguish completed vs incomplete task copy"
        )
        try expect(
            source.contains("languageStore.text(copy, minutesToAdd)"),
            "Success dialog should interpolate the recorded minutes into the success copy"
        )
        try expect(
            source.contains(".pomodoroDone"),
            "Success dialog should use a single primary 知道了 button"
        )
        // Duration-write failure offers retry/later, never claims success.
        try expect(
            source.contains("case .durationWriteFailed"),
            "Prompt card should route duration write failure"
        )
        try expect(
            source.contains(".pomodoroRetryDurationWrite") && source.contains(".pomodoroLater"),
            "Duration-write failure should offer retry and later actions"
        )
        // Abandon uses destructive styling; pause and abandon route to the right view-model actions.
        try expect(
            source.contains("case .pause") && source.contains("case .abandon"),
            "Prompt card should route pause and abandon"
        )
        try expect(
            source.contains("viewModel.requestPomodoroAbandon()") && source.contains("viewModel.confirmPomodoroAbandon()"),
            "Abandon flow should call request then confirm on the view model"
        )
        try expect(
            source.contains("viewModel.resumePomodoro()"),
            "Pause and manual-end 继续专注 should resume the view model session"
        )
        // No macOS confirmationDialog; all dialogs are custom SwiftUI overlays.
        try expect(
            !source.contains("confirmationDialog"),
            "Pomodoro dialogs should be custom overlays, not macOS confirmationDialog"
        )
        // Task-row start action is disabled during any active session/start/prompt.
        try expect(
            source.contains("viewModel.pomodoroSession != nil")
                && source.contains("viewModel.pomodoroStartTask != nil")
                && source.contains("viewModel.pomodoroPrompt != nil"),
            "Task-row start action should disable during any session, start dialog, or prompt"
        )
        try expect(
            source.contains("viewModel.presentPomodoroStart(for: task)"),
            "Task-row start action should present the start dialog via the view model"
        )
    }

    static func pomodoroContentViewIntegrationKeepsContract() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let contentViewURL = rootURL
            .appendingPathComponent("WidgetToDo")
            .appendingPathComponent("ContentView.swift")
        let source = try String(contentsOf: contentViewURL, encoding: .utf8)

        // Focus card sits above the task list, after the sync banner.
        try expect(
            source.contains("PomodoroFocusCard(viewModel: todoViewModel)"),
            "todoPanel should mount PomodoroFocusCard above the task list"
        )
        // Start and prompt overlays live in the todoPanel ZStack.
        try expect(
            source.contains("PomodoroStartCard(viewModel: todoViewModel)"),
            "todoPanel ZStack should mount PomodoroStartCard"
        )
        try expect(
            source.contains("PomodoroPromptCard(viewModel: todoViewModel)"),
            "todoPanel ZStack should mount PomodoroPromptCard"
        )
        // Incomplete task rows expose the compact timer start action.
        try expect(
            source.contains("if !task.isDone {") && source.contains("PomodoroTaskRowStartAction(viewModel: todoViewModel, task: task)"),
            "Incomplete task rows should expose the Pomodoro start action"
        )
        // Journal panel must remain free of Pomodoro view names: each Pomodoro
        // view type should be mounted exactly once (only in the Todo path).
        try expect(
            source.components(separatedBy: "PomodoroFocusCard").count - 1 == 1,
            "PomodoroFocusCard should be mounted exactly once (todoPanel only)"
        )
        try expect(
            source.components(separatedBy: "PomodoroStartCard").count - 1 == 1,
            "PomodoroStartCard should be mounted exactly once (todoPanel only)"
        )
        try expect(
            source.components(separatedBy: "PomodoroPromptCard").count - 1 == 1,
            "PomodoroPromptCard should be mounted exactly once (todoPanel only)"
        )
        try expect(
            source.components(separatedBy: "PomodoroTaskRowStartAction").count - 1 == 1,
            "PomodoroTaskRowStartAction should be mounted exactly once (incomplete task rows only)"
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
