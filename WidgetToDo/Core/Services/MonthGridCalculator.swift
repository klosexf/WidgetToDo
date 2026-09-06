import Foundation

/// 月历网格的纯计算：给定某月任意一天，产出「固定首列起始、相邻月补位」的网格日期序列。
/// 日期↔星期几的映射全部集中在这里（视图层只渲染不计算），便于 `swift test` 覆盖
/// 不同月份、闰年、百年闰与跨年滚动场景。
public struct MonthGridCalculator: Sendable {

    /// 网格中的单格：真实连续日期 + 是否属于当前展示月份。
    public struct GridDay: Equatable, Hashable, Sendable {
        public let date: Date
        public let isInMonth: Bool
    }

    public let calendar: Calendar

    /// - Parameters:
    ///   - firstWeekday: 网格首列是周几（1=周日 … 7=周六），默认 2 = 周一起始。
    ///   - timezone: 固定时区（测试确定性用）；nil = 跟随系统当前时区。
    public init(firstWeekday: Int = 2, timezone: TimeZone? = nil) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = firstWeekday
        if let timezone {
            calendar.timeZone = timezone
        }
        self.calendar = calendar
    }

    /// 该日期所在月份的 1 号（当日零点）。
    public func monthStart(containing date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    /// 月首前需要补位的天数：把月首推到网格首列（周一起始时周一=0，周二=1 …）。
    public func leadingBlankCount(forMonthContaining date: Date) -> Int {
        let weekday = calendar.component(.weekday, from: monthStart(containing: date))
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    /// 当月天数（闰年/大小月由 Calendar 处理）。
    public func daysInMonth(forMonthContaining date: Date) -> Int {
        calendar.range(of: .day, in: .month, for: monthStart(containing: date))?.count ?? 0
    }

    /// 完整网格：从首列开始的真实连续日期，一天一格、绝无镂空。
    /// 前导为上月尾部，末尾补下月开头，总格数凑满整周；相邻月日期 `isInMonth == false`。
    public func gridDays(forMonthContaining date: Date) -> [GridDay] {
        let lead = leadingBlankCount(forMonthContaining: date)
        let dayCount = daysInMonth(forMonthContaining: date)
        let total = lead + dayCount
        let slots = total % 7 == 0 ? total : total + (7 - total % 7)

        guard let gridStart = calendar.date(byAdding: .day, value: -lead, to: monthStart(containing: date)) else {
            return []
        }

        return (0..<slots).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: gridStart) else { return nil }
            let isInMonth = offset >= lead && offset < lead + dayCount
            return GridDay(date: day, isInMonth: isInMonth)
        }
    }

    /// 表头星期符号：把系统符号（固定周日起始 [日, 一, …, 六]）按 firstWeekday 旋转。
    /// 例如周一起始 + zh_Hans → [一, 二, 三, 四, 五, 六, 日]。
    public static func weekdaySymbols(firstWeekday: Int, locale: Locale) -> [String] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        let symbols = calendar.veryShortWeekdaySymbols
        let firstIndex = max(0, min(6, firstWeekday - 1))
        return Array(symbols[firstIndex...] + symbols[..<firstIndex])
    }
}
