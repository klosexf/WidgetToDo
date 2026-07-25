import XCTest
@testable import NotionFloatCore

final class FieldMappingResolutionTests: XCTestCase {
    func testResolveTaskFieldMappingUsesUniqueRequiredTypesAndOptionalSingleSelect() {
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
            XCTAssertEqual(
                mapping,
                TaskDatabaseFieldMapping(
                    title: "任务标题",
                    date: "计划日期",
                    done: "已完成",
                    priority: "任务优先级",
                    estimatedMinutes: nil
                )
            )
        default:
            XCTFail("Expected successful task field mapping resolution")
        }
    }

    func testResolveTaskFieldMappingReportsMissingRequiredType() {
        let result = FieldValidator.resolve(
            [
                NotionPropertySchema(name: "任务标题", type: "title"),
                NotionPropertySchema(name: "已完成", type: "checkbox")
            ],
            for: .tasks
        )

        switch result {
        case let .failure(issues):
            XCTAssertEqual(issues.map(\.message.key), [.missingRequiredFieldType])
            XCTAssertEqual(issues.map(\.message.arguments), [["date"]])
        default:
            XCTFail("Expected missing date type failure")
        }
    }

    func testResolveTaskFieldMappingReportsAmbiguousRequiredTypeNames() {
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
            XCTAssertEqual(
                issues.map(\.message.key),
                [.duplicateRequiredField]
            )
            XCTAssertEqual(issues.map(\.message.arguments), [["date", "开始时间, 截止时间", "date"]])
        default:
            XCTFail("Expected ambiguous task date field failure")
        }
    }

    func testResolveTaskFieldMappingDisablesPriorityWhenMultipleSelectFieldsExist() {
        let result = FieldValidator.resolve(
            [
                NotionPropertySchema(name: "任务标题", type: "title"),
                NotionPropertySchema(name: "计划日期", type: "date"),
                NotionPropertySchema(name: "已完成", type: "checkbox"),
                NotionPropertySchema(name: "优先级", type: "select"),
                NotionPropertySchema(name: "所属项目", type: "select")
            ],
            for: .tasks
        )

        switch result {
        case let .success(.tasks(mapping)):
            XCTAssertNil(mapping.priority)
        default:
            XCTFail("Expected priority mapping to be omitted instead of failing")
        }
    }

    func testResolveTaskFieldMappingUsesUniqueOptionalNumberAsEstimatedMinutes() {
        let result = FieldValidator.resolve(
            [
                NotionPropertySchema(name: "任务标题", type: "title"),
                NotionPropertySchema(name: "计划日期", type: "date"),
                NotionPropertySchema(name: "已完成", type: "checkbox"),
                NotionPropertySchema(name: "任务优先级", type: "select"),
                NotionPropertySchema(name: "预计时长", type: "number")
            ],
            for: .tasks
        )

        switch result {
        case let .success(.tasks(mapping)):
            XCTAssertEqual(
                mapping,
                TaskDatabaseFieldMapping(
                    title: "任务标题",
                    date: "计划日期",
                    done: "已完成",
                    priority: "任务优先级",
                    estimatedMinutes: "预计时长"
                )
            )
        default:
            XCTFail("Expected estimated minutes mapping to resolve from the unique number field")
        }
    }

    func testResolveTaskFieldMappingDisablesEstimatedMinutesWhenMultipleNumberFieldsExist() {
        let result = FieldValidator.resolve(
            [
                NotionPropertySchema(name: "任务标题", type: "title"),
                NotionPropertySchema(name: "计划日期", type: "date"),
                NotionPropertySchema(name: "已完成", type: "checkbox"),
                NotionPropertySchema(name: "预计时长", type: "number"),
                NotionPropertySchema(name: "实际时长", type: "number")
            ],
            for: .tasks
        )

        switch result {
        case let .success(.tasks(mapping)):
            XCTAssertNil(mapping.estimatedMinutes)
        default:
            XCTFail("Expected estimated minutes mapping to be omitted instead of failing")
        }
    }

    func testAppSettingsDecodesLegacyPayloadWithDefaultFieldMappings() throws {
        let json = #"""
        {
          "tasksDatabaseID": "tasks-db",
          "journalDatabaseID": "journal-db",
          "lastValidatedAt": "2026-06-02T08:30:00Z",
          "hasPriorityField": true
        }
        """#

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let settings = try decoder.decode(AppSettings.self, from: Data(json.utf8))

        XCTAssertEqual(settings.tasksFieldMapping, .legacyDefault)
        XCTAssertEqual(settings.journalFieldMapping, .legacyDefault)
    }
}
