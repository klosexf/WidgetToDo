import SwiftUI

struct MiniCapsuleContainer<Leading: View>: View {
    let title: String
    let subtitle: String
    let onExpand: () -> Void
    let onClose: () -> Void
    @ViewBuilder let leading: Leading

    var body: some View {
        HStack(spacing: 10) {
            leading
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(MiniCapsulePalette.titleText)
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(MiniCapsulePalette.subtitleText)
            }

            Spacer()

            Button {
                onExpand()
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MiniCapsulePalette.actionText)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MiniCapsulePalette.actionText)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        }
        .padding(.horizontal, 10)
        .frame(width: 220, height: 56)
        .background(MiniCapsulePalette.background)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(MiniCapsulePalette.border, lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
        .contentShape(Rectangle())
        .onTapGesture {
            onExpand()
        }
    }
}

struct TodoMiniCapsuleView: View {
    let completedCount: Int
    let totalCount: Int
    let onExpand: () -> Void
    let onClose: () -> Void

    private var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    var body: some View {
        MiniCapsuleContainer(
            title: "今日待办",
            subtitle: "\(completedCount)/\(totalCount) 已完成",
            onExpand: onExpand,
            onClose: onClose
        ) {
            MiniProgressRing(progress: progress)
        }
    }
}

struct JournalMiniCapsuleView: View {
    let wordCount: Int
    let statusMessage: String?
    let onExpand: () -> Void
    let onClose: () -> Void

    private var subtitle: String {
        let countText = "\(wordCount) 字"
        if let statusMessage, !statusMessage.isEmpty {
            return "\(countText) · \(statusMessage)"
        }
        return countText
    }

    var body: some View {
        MiniCapsuleContainer(
            title: "今日日记",
            subtitle: subtitle,
            onExpand: onExpand,
            onClose: onClose
        ) {
            Image(systemName: "book")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(MiniCapsulePalette.accent)
        }
    }
}

struct MiniProgressRing: View {
    let progress: Double
    private let lineWidth: CGFloat = 4.5
    private let ringSize: CGFloat = 36

    var body: some View {
        ZStack {
            Circle()
                .stroke(MiniCapsulePalette.ringBackground, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(progress, 0), 1)))
                .stroke(
                    MiniCapsulePalette.ringFill,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: ringSize, height: ringSize)
    }
}

private enum MiniCapsulePalette {
    static let background = Color.white
    static let border = Color(red: 0.89, green: 0.87, blue: 0.85).opacity(0.92)
    static let titleText = Color(red: 0.129, green: 0.125, blue: 0.122)
    static let subtitleText = Color(red: 0.545, green: 0.522, blue: 0.494)
    static let actionText = Color(red: 0.47, green: 0.459, blue: 0.447)
    static let accent = Color(red: 0.129, green: 0.125, blue: 0.122)
    static let ringBackground = Color(red: 0.914, green: 0.894, blue: 0.875)
    static let ringFill = Color(red: 0.22, green: 0.74, blue: 0.34)
}
