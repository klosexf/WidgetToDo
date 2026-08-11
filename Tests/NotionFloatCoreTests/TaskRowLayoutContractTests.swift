import Foundation
import XCTest

final class TaskRowLayoutContractTests: XCTestCase {
    func testTaskRowMetaElementsUseFourPointSpacing() throws {
        let source = try String(contentsOf: contentViewURL(), encoding: .utf8)

        XCTAssertTrue(source.contains("static let taskRowMetaSpacing: CGFloat = 4"))
    }

    func testTaskRowKeepsDurationOnOneLineBeforeCompressingChoiceValue() throws {
        let source = try String(contentsOf: contentViewURL(), encoding: .utf8)

        XCTAssertTrue(source.contains(".lineLimit(1)"))
        XCTAssertTrue(source.contains(".fixedSize(horizontal: true, vertical: false)"))
        XCTAssertFalse(source.contains(".layoutPriority(-1)"))
        let taskTitleStart = try XCTUnwrap(source.range(of: "Text(task.title)"))
        let taskRowEnd = try XCTUnwrap(source[taskTitleStart.lowerBound...].range(of: "\n                Spacer()"))
        let taskContent = String(source[taskTitleStart.lowerBound..<taskRowEnd.lowerBound])
        XCTAssertTrue(taskContent.contains(".frame(maxWidth: .infinity, alignment: .leading)"))

        let taskRowStart = try XCTUnwrap(source.range(of: "private func taskRowView"))
        let trailingActionsStart = try XCTUnwrap(source[taskRowStart.lowerBound...].range(of: "HStack(spacing: FloatingWidgetMetrics.taskRowActionSpacing)"))
        let leadingTaskArea = String(source[taskRowStart.lowerBound..<trailingActionsStart.lowerBound])
        XCTAssertTrue(leadingTaskArea.contains(".contentShape(Rectangle())\n            .layoutPriority(1)"))

        let trailingTaskArea = String(source[trailingActionsStart.lowerBound...])
        XCTAssertTrue(trailingTaskArea.contains(".fixedSize(horizontal: true, vertical: false)"))

        let choiceLabelStart = try XCTUnwrap(source.range(of: "if let priority = task.priority, let choiceOption"))
        let choiceLabelEnd = try XCTUnwrap(source[choiceLabelStart.lowerBound...].range(of: "\n\n                        if choiceOption != nil"))
        let choiceLabel = String(source[choiceLabelStart.lowerBound..<choiceLabelEnd.lowerBound])
        XCTAssertFalse(choiceLabel.contains("Circle().fill"))
        XCTAssertTrue(choiceLabel.contains("TaskChoicePalette.dot(for: choiceOption).opacity(0.14)"))
        XCTAssertFalse(choiceLabel.contains(".frame(minWidth: 0, maxWidth: 142)"))
    }

    private func contentViewURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("WidgetToDo/ContentView.swift")
    }
}
