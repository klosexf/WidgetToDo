import Foundation

public enum TodoDateDisplayFormatter {
    public static func title(
        for selectedDate: Date,
        today: Date = Date(),
        calendar: Calendar = Calendar(identifier: .gregorian),
        language: AppLanguage = .default
    ) -> String {
        monthDayString(for: selectedDate, language: language)
    }

    public static func emptyStateTitle(
        for selectedDate: Date,
        today: Date = Date(),
        calendar: Calendar = Calendar(identifier: .gregorian),
        language: AppLanguage = .default
    ) -> String {
        if calendar.isDate(selectedDate, inSameDayAs: today) {
            return AppText.string(.noTasksToday, language: language)
        }
        return AppText.string(
            .noTasksOnDate,
            language: language,
            arguments: [monthDayString(for: selectedDate, language: language)]
        )
    }

    public static func monthDayString(for date: Date, language: AppLanguage = .default) -> String {
        date.formatted(
            .dateTime
                .month()
                .day()
                .locale(language.locale)
        )
    }
}
