import SwiftUI

private enum PendingPalette {
    static let checkBorder = Color(red: 189/255, green: 182/255, blue: 175/255)
    static let checkBg = Color.white.opacity(0.92)
    static let hourglassColor = Color(red: 139/255, green: 133/255, blue: 126/255)
    static let titleColor = Color(red: 35/255, green: 34/255, blue: 33/255).opacity(0.5)
    static let metaText = Color(red: 139/255, green: 133/255, blue: 126/255)
    static let durationText = Color(red: 0.78, green: 0.45, blue: 0.14)
    static let durationBg = Color(red: 0.996, green: 0.949, blue: 0.886)
    static let failureOverlay = Color.red.opacity(0.2)
}

struct PendingTodoRowView: View {
    let item: PendingTaskItem
    let showFailure: Bool
    @EnvironmentObject private var languageStore: LanguageStore

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
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

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PendingPalette.titleColor)
                    .lineLimit(1)
                    .truncationMode(.tail)

                HStack(spacing: 6) {
                    if let estimatedMinutes = item.estimatedMinutes {
                        Text(languageStore.text(.minutesValue, estimatedMinutes))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(PendingPalette.durationText)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(PendingPalette.durationBg)
                            )
                    }

                    if item.estimatedMinutes != nil {
                        Text("·")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(PendingPalette.metaText)
                    }

                    Text(languageStore.text(showFailure ? .syncFailed : .syncSyncing))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(showFailure ? .red : PendingPalette.metaText)
                }
            }

            Spacer()
        }
        .background(showFailure ? PendingPalette.failureOverlay : Color.clear)
        .animation(.easeInOut(duration: 0.3), value: showFailure)
    }
}
