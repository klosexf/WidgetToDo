import SwiftUI

private enum PendingPalette {
    static let checkBorder = Color(red: 189/255, green: 182/255, blue: 175/255)
    static let checkBg = Color.white.opacity(0.92)
    static let hourglassColor = Color(red: 139/255, green: 133/255, blue: 126/255)
    static let titleColor = Color(red: 35/255, green: 34/255, blue: 33/255).opacity(0.5)
    static let priorityBg = Color(red: 234/255, green: 242/255, blue: 255/255)
    static let priorityText = Color(red: 34/255, green: 33/255, blue: 32/255)
    static let metaText = Color(red: 139/255, green: 133/255, blue: 126/255)
    static let failureOverlay = Color.red.opacity(0.2)
}

struct PendingTodoRowView: View {
    let item: PendingTaskItem
    let showFailure: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(PendingPalette.checkBg)
                    .frame(width: 16, height: 16)
                Circle()
                    .stroke(PendingPalette.checkBorder, lineWidth: 1.5)
                    .frame(width: 16, height: 16)
                Image(systemName: "hourglass")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(PendingPalette.hourglassColor)
            }
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PendingPalette.titleColor)

                HStack(spacing: 6) {
                    if let priority = item.priority {
                        Text(priority)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(PendingPalette.priorityText)
                            .frame(minWidth: 24)
                            .frame(height: 20)
                            .padding(.horizontal, 7)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(PendingPalette.priorityBg)
                            )
                    }

                    Text(
                        item.date.formatted(
                            .dateTime
                                .year()
                                .month()
                                .day()
                                .locale(Locale(identifier: "zh_CN"))
                        )
                    )
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(PendingPalette.metaText)
                }
            }

            Spacer()
        }
        .background(showFailure ? PendingPalette.failureOverlay : Color.clear)
        .animation(.easeInOut(duration: 0.3), value: showFailure)
    }
}
