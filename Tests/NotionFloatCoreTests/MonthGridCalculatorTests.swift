import XCTest
@testable import NotionFloatCore

/// 月历网格的日期↔星期映射契约：
/// 任何月份、闰年、百年闰、跨年滚动下，每一格的列位置都必须等于真实星期，
/// 网格必须是连续日期且无镂空。
final class MonthGridCalculatorTests: XCTestCase {

    private var calculator: MonthGridCalculator!
    private var utc: Calendar!

    override func setUp() {
        super.setUp()
        let utcZone = TimeZone(identifier: "UTC")!
        calculator = MonthGridCalculator(timezone: utcZone)
        utc = Calendar(identifier: .gregorian)
        utc.timeZone = utcZone
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        utc.date(from: DateComponents(timeZone: utc.timeZone, year: year, month: month, day: day))!
    }

    /// 核心契约：网格第 index 格的列 = 该日期真实星期在周一起始下的列。
    /// 该测试能直接抓出「表头旋转方向错误 / 列错位」类 bug。
    func testGridColumnsMatchRealWeekdaysAcrossMonthsAndYears() {
        let monthAnchors = [
            date(2026, 7, 15), date(2026, 8, 15), date(2026, 9, 15),
            date(2026, 12, 15), date(2027, 1, 15),
            date(2024, 2, 15), date(2023, 2, 15),
            date(2000, 2, 15), date(2100, 2, 15)
        ]
        for anchor in monthAnchors {
            let days = calculator.gridDays(forMonthContaining: anchor)
            XCTAssertFalse(days.isEmpty)
            XCTAssertEqual(days.count % 7, 0, "网格必须凑满整周: \(anchor)")
            for (index, day) in days.enumerated() {
                let weekday = utc.component(.weekday, from: day.date)
                let expectedColumn = (weekday - calculator.calendar.firstWeekday + 7) % 7
                XCTAssertEqual(index % 7, expectedColumn, "列错位: \(day.date)")
            }
        }
    }

    func testJuly2026StartsWednesdayWithJuneFill() {
        XCTAssertEqual(calculator.leadingBlankCount(forMonthContaining: date(2026, 7, 1)), 2, "7月1日是周三，周一起始需补 2 格")
        let days = calculator.gridDays(forMonthContaining: date(2026, 7, 1))
        XCTAssertEqual(days.count, 35)
        XCTAssertEqual(days.first?.date, date(2026, 6, 29), "首位应为 6月29日（周一）")
        XCTAssertFalse(days[0].isInMonth)
        XCTAssertEqual(days[2].date, date(2026, 7, 1), "7月1日必须落在周三列")
        XCTAssertTrue(days[2].isInMonth)
        XCTAssertEqual(days.last?.date, date(2026, 8, 2), "末位应为 8月2日（周日）")
    }

    func testAugust2026StartsSaturdayWithLongLead() {
        XCTAssertEqual(calculator.leadingBlankCount(forMonthContaining: date(2026, 8, 1)), 5, "8月1日是周六，周一起始需补 5 格")
        let days = calculator.gridDays(forMonthContaining: date(2026, 8, 1))
        XCTAssertEqual(days.count, 42)
        XCTAssertEqual(days.first?.date, date(2026, 7, 27), "首位应为 7月27日（周一）")
        XCTAssertEqual(days[5].date, date(2026, 8, 1), "8月1日必须落在周六列")
        XCTAssertEqual(days.last?.date, date(2026, 9, 6))
    }

    func testLeapYearFebruary2024Has29Days() {
        XCTAssertEqual(calculator.daysInMonth(forMonthContaining: date(2024, 2, 15)), 29)
        let days = calculator.gridDays(forMonthContaining: date(2024, 2, 1))
        XCTAssertTrue(days.contains { utc.isDate($0.date, inSameDayAs: date(2024, 2, 29)) }, "闰年 2月29日必须出现在网格中")
        XCTAssertEqual(days.last?.date, date(2024, 3, 3))
    }

    func testNonLeapYearFebruary2023Has28Days() {
        XCTAssertEqual(calculator.daysInMonth(forMonthContaining: date(2023, 2, 15)), 28)
        let days = calculator.gridDays(forMonthContaining: date(2023, 2, 1))
        // 平年 2月28日的下一天必须直接是 3月1日（不能用 date(2023,2,29) 断言——
        // Calendar 会把它归一化成 3月1日，导致断言对象不存在）。
        let feb28Index = days.firstIndex { utc.isDate($0.date, inSameDayAs: date(2023, 2, 28)) }
        XCTAssertNotNil(feb28Index)
        XCTAssertEqual(days[feb28Index! + 1].date, date(2023, 3, 1), "平年 2月28日的下一天就是 3月1日")
    }

    func testLeapCenturyFebruary2000Has29Days() {
        XCTAssertEqual(calculator.daysInMonth(forMonthContaining: date(2000, 2, 15)), 29, "2000 能被 400 整除，是闰年")
        XCTAssertEqual(utc.component(.weekday, from: date(2000, 2, 29)), 3, "2000-02-29 是周二")
    }

    func testNonLeapCenturyFebruary2100Has28Days() {
        XCTAssertEqual(calculator.daysInMonth(forMonthContaining: date(2100, 2, 15)), 28, "2100 不能被 400 整除，是平年")
    }

    func testDecemberRolloverFillsNextYearJanuary() {
        let days = calculator.gridDays(forMonthContaining: date(2026, 12, 15))
        XCTAssertEqual(days.first?.date, date(2026, 11, 30))
        XCTAssertEqual(days.last?.date, date(2027, 1, 3), "12月网格尾部应补次年 1 月日期")
    }

    func testGridDaysAreStrictlyConsecutive() {
        let days = calculator.gridDays(forMonthContaining: date(2026, 9, 15))
        for pair in zip(days, days.dropFirst()) {
            XCTAssertEqual(
                pair.1.date.timeIntervalSince(pair.0.date),
                86_400,
                accuracy: 0.5,
                "网格日期必须一天一格连续"
            )
        }
    }

    func testInMonthFlagsMatchDaysInMonth() {
        let days = calculator.gridDays(forMonthContaining: date(2026, 7, 15))
        XCTAssertEqual(days.filter(\.isInMonth).count, 31)
    }

    func testWeekdaySymbolsRotation() {
        XCTAssertEqual(
            MonthGridCalculator.weekdaySymbols(firstWeekday: 2, locale: Locale(identifier: "zh_Hans")),
            ["一", "二", "三", "四", "五", "六", "日"],
            "周一起始的中文表头必须是一二三四五六日"
        )
        XCTAssertEqual(
            MonthGridCalculator.weekdaySymbols(firstWeekday: 1, locale: Locale(identifier: "zh_Hans")),
            ["日", "一", "二", "三", "四", "五", "六"],
            "周日起始的中文表头必须是日一二三四五六"
        )
    }
}
