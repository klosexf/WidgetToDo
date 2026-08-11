import Foundation
import XCTest

final class TaskRowLayoutContractTests: XCTestCase {
    func testTaskRowKeepsDurationOnOneLineBeforeCompressingChoiceValue() throws {
        let source = try String(contentsOf: contentViewURL(), encoding: .utf8)

        XCTAssertTrue(source.contains(".lineLimit(1)"))
        XCTAssertTrue(source.contains(".fixedSize(horizontal: true, vertical: false)"))
        XCTAssertTrue(source.contains(".frame(minWidth: 0, maxWidth: 142)"))
        XCTAssertFalse(source.contains(".layoutPriority(-1)"))
        let taskTitleStart = try XCTUnwrap(source.range(of: "Text(task.title)"))
        let taskRowEnd = try XCTUnwrap(source[taskTitleStart.lowerBound...].range(of: "\n                Spacer()"))
        let taskContent = String(source[taskTitleStart.lowerBound..<taskRowEnd.lowerBound])
        XCTAssertTrue(taskContent.contains(".frame(maxWidth: .infinity, alignment: .leading)"))

        let taskRowStart = try XCTUnwrap(source.range(of: "private func taskRowView"))
        let trailingActionsStart = try XCTUnwrap(source[taskRowStart.lowerBound...].range(of: "HStack(spacing: FloatingWidgetMetrics.taskRowActionSpacing)"))
        let leadingTaskArea = String(source[taskRowStart.lowerBound..<trailingActionsStart.lowerBound])
        XCTAssertTrue(leadingTaskArea.contains(".contentShape(Rectangle())\n            .layoutPriority(1)"))
    }

    private func contentViewURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("WidgetToDo/ContentView.swift")
    }
}
