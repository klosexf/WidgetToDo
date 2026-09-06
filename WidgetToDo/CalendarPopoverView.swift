import SwiftUI
import AppKit

/// 月历弹层的单日印记：只表达「有无」，不表达数量。
struct CalendarDayMark: Equatable {
    let hasTasks: Bool
    let hasJournal: Bool

    var isEmpty: Bool { !hasTasks && !hasJournal }
}

/// 月历弹层所属的模块上下文：决定展示哪一类专属印记。
/// 待办 tab 只显示任务印记（棕点），日记 tab 只显示日记印记（蓝横），
/// 两者永不混排；视觉框架保持一致，靠印记样式直观区分内容类型。
enum CalendarMarkContext {
    case todo
    case journal
}

/// 方案二「暖纸」月历弹层：点日期行展开，按月展示每一天，
/// 印记按模块上下文显示——待办 tab 带任务圆点、日记 tab 带日记短横；点某天跳转到该日期。
/// 日期↔星期几的映射与补位全部委托给 `MonthGridCalculator`（纯计算，可单测），
/// 网格用真实连续日期填充：相邻月日期浅灰补位，任何月份都不出现镂空。
struct CalendarPopoverView: View {
    let language: AppLanguage
    /// 当月任意一天（内部归一到当月 1 号）。
    let month: Date
    let selectedDate: Date
    /// day -> 印记（只示有无），仅当前展示月份的日期有印记。
    let marks: [Int: CalendarDayMark]
    /// 当前模块上下文：决定印记/图例/统计条只展示对应类型。
    let context: CalendarMarkContext
    let textProvider: (AppText.Key) -> String
    let onPickDay: (Date) -> Void
    let onChangeMonth: (Int) -> Void
    let onPickToday: () -> Void

    private let gridCalculator = MonthGridCalculator()

    private var monthStart: Date {
        gridCalculator.monthStart(containing: month)
    }

    private static let monthTitleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "y年M月"
        return formatter
    }()

    private var monthTitle: String {
        let formatter = Self.monthTitleFormatter
        let previous = formatter.locale
        formatter.locale = language.locale
        let title = formatter.string(from: monthStart)
        formatter.locale = previous
        return title
    }

    /// 当前上下文的印记天数：待办 tab 数任务天数，日记 tab 数日记天数。
    private var contextMarkDays: Int {
        switch context {
        case .todo:
            return marks.values.filter(\.hasTasks).count
        case .journal:
            return marks.values.filter(\.hasJournal).count
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
                ForEach(MonthGridCalculator.weekdaySymbols(
                    firstWeekday: gridCalculator.calendar.firstWeekday,
                    locale: language.locale
                ), id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(Color(red: 0.639, green: 0.612, blue: 0.573))
                        .frame(maxWidth: .infinity)
                }

                ForEach(gridCalculator.gridDays(forMonthContaining: month), id: \.self) { cell in
                    dayCell(cell)
                }
            }

            footer
        }
        .padding(14)
        .frame(width: 300)
        .background(
            // 苹果原生质感：厚半透明材质背景（高斯模糊，像系统 popover/通知中心浮层），
            // 上面叠一层极淡的暖纸色调，保留产品暖灰语言又不失系统感。
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.thickMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(red: 0.984, green: 0.976, blue: 0.957).opacity(0.42))
                )
                .overlay(
                    // 顶部微光边缘（原生 popover 的高光描边质感）
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.55), Color.white.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                )
        )
        // 柔和多层阴影：贴合 macOS 浮层的「轻轻托起」感
        .shadow(color: .black.opacity(0.08), radius: 2, y: 0.5)
        .shadow(color: Color(red: 0.47, green: 0.353, blue: 0.235).opacity(0.22), radius: 28, y: 12)
        // 弹层内所有 Text 禁用文本选择——去掉 macOS 给可选文本加的 I-beam 光标，
        // 让日期数字/星期表头/标题呈现默认箭头（这是根治 I-beam 的标准做法，
        // onHover+NSCursor 在 Text/Button 的 NSTrackingArea 面前会被抢回去）。
        .textSelection(.disabled)
        // 容器空白处（格子间隙、padding）压栈箭头，兜底 I-beam。
        .cursor(.arrow)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(monthTitle)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(red: 0.129, green: 0.125, blue: 0.122))

                // 图例按模块上下文只显示对应一项：待办→● 任务，日记→▬ 日记。
                HStack(spacing: 3) {
                    switch context {
                    case .todo:
                        Circle()
                            .fill(Color(red: 0.69, green: 0.561, blue: 0.42))
                            .frame(width: 3, height: 3)
                        Text(textProvider(.taskLabel))
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(Color(red: 0.639, green: 0.612, blue: 0.573))
                    case .journal:
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color(red: 0.478, green: 0.612, blue: 0.776))
                            .frame(width: 5, height: 2.5)
                        Text(textProvider(.journalTab))
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(Color(red: 0.639, green: 0.612, blue: 0.573))
                    }
                }
            }

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                Button {
                    onPickToday()
                } label: {
                    Text(textProvider(.backToToday))
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Color(red: 0.569, green: 0.42, blue: 0.322))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.white)
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color(red: 0.89, green: 0.851, blue: 0.776), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .cursor(.pointingHand)

                monthArrow(direction: -1)
                monthArrow(direction: 1)
            }
        }
        .padding(.bottom, 8)
    }

    private func monthArrow(direction: Int) -> some View {
        Button {
            onChangeMonth(direction)
        } label: {
            Image(systemName: direction < 0 ? "chevron.left" : "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color(red: 0.639, green: 0.612, blue: 0.573))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .cursor(.pointingHand)
    }

    // MARK: - Day Cells

    private static let dayCellHeight: CGFloat = 38

    private func dayCell(_ cell: MonthGridCalculator.GridDay) -> some View {
        let date = cell.date
        let day = gridCalculator.calendar.component(.day, from: date)
        let isSelected = gridCalculator.calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = gridCalculator.calendar.isDateInToday(date)
        let mark = cell.isInMonth ? marks[day] : nil

        return Button {
            onPickDay(date)
        } label: {
            VStack(spacing: 2) {
                Text("\(day)")
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(
                        isSelected
                            ? Color.white
                            : (cell.isInMonth
                                ? Color(red: 0.29, green: 0.271, blue: 0.239)
                                : Color(red: 0.733, green: 0.714, blue: 0.682))
                    )

                markIndicator(mark, isSelected: isSelected)
            }
            .frame(maxWidth: .infinity)
            .frame(height: CalendarPopoverView.dayCellHeight)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(Color(red: 0.569, green: 0.42, blue: 0.322))
                    }
                }
            )
            .overlay(
                Group {
                    if isToday && !isSelected {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(Color(red: 0.569, green: 0.42, blue: 0.322), lineWidth: 1.5)
                    }
                }
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .cursor(.pointingHand)
    }

    /// 当前上下文是否该显示该格印记：待办 tab 看有任务，日记 tab 看有日记。
    private func shouldShowMark(_ mark: CalendarDayMark?) -> Bool {
        switch context {
        case .todo: return mark?.hasTasks == true
        case .journal: return mark?.hasJournal == true
        }
    }

    @ViewBuilder
    private func markIndicator(_ mark: CalendarDayMark?, isSelected: Bool) -> some View {
        // 印记按模块上下文只显示对应类型：待办 tab 只画任务圆点，
        // 日记 tab 只画日记短横，两类印记不会同时出现在同一格。
        if shouldShowMark(mark) {
            Group {
                switch context {
                case .todo:
                    Circle()
                        .fill(
                            isSelected
                                ? Color.white.opacity(0.85)
                                : Color(red: 0.69, green: 0.561, blue: 0.42)
                        )
                        .frame(width: 3, height: 3)
                case .journal:
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(
                            isSelected
                                ? Color.white.opacity(0.85)
                                : Color(red: 0.478, green: 0.612, blue: 0.776)
                        )
                        .frame(width: 5, height: 2.5)
                }
            }
            .frame(height: 3)
        } else {
            Color.clear.frame(height: 3)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        // 统计条按模块上下文只统计/展示对应维度的天数。
        HStack {
            switch context {
            case .todo:
                Text(String(format: textProvider(.calendarDaysWithTasks), "\(contextMarkDays)"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .journal:
                Text(String(format: textProvider(.calendarDaysWithJournal), "\(contextMarkDays)"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .font(.system(size: 10.5, weight: .medium))
        .foregroundStyle(Color(red: 0.639, green: 0.612, blue: 0.573))
        .padding(.top, 8)
        .padding(.horizontal, 2)
        .overlay(
            Rectangle()
                .fill(Color(red: 0.937, green: 0.914, blue: 0.863))
                .frame(height: 0.5)
                .offset(y: -4),
            alignment: .top
        )
    }
}

extension View {
    /// 悬停时把系统光标固定为指定形状：macOS 的 SwiftUI `Text` 悬停默认呈
    /// 文本选取光标（I-beam），交互区需要显式覆盖。
    ///
    /// 用 `push()`/`pop()` 光标栈而不是 `set()`：嵌套视图（如弹层容器=箭头、
    /// 内部日期格=手型）进入时各自 push，退出时 pop 自动回到上一层光标，
    /// 不会互相踩掉；`set()` 在嵌套+快速移动时会把光标卡在错误形状。
    func cursor(_ shape: NSCursor) -> some View {
        onHover { hovering in
            if hovering {
                shape.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
