import Foundation

public enum TodoDateDisplayFormatter {
    public static func title(
        for selectedDate: Date,
        today: Date = Date(),
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> String {
        if calendar.isDate(selectedDate, inSameDayAs: today) {
            return "今天\(monthDayString(for: selectedDate))"
        }
        return monthDayString(for: selectedDate)
    }

    public static func emptyStateTitle(
        for selectedDate: Date,
        today: Date = Date(),
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> String {
        if calendar.isDate(selectedDate, inSameDayAs: today) {
            return "今天没有任务"
        }
        return "\(monthDayString(for: selectedDate)) 没有任务"
    }

    public static func monthDayString(for date: Date) -> String {
        date.formatted(
            .dateTime
                .month()
                .day()
                .locale(Locale(identifier: "zh_CN"))
        )
    }
}
