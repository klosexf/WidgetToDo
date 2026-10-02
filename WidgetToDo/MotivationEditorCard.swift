import SwiftUI

/// 激励话术的编辑弹框：多行输入 + 字数 + 取消/保存。
///
/// 壳层尺寸、配色、按钮样式全部对齐既有的 `NewTaskFormCard` / `EditTaskFormCard`
/// （`NewTaskFormCard.swift:3-30`、`:51-81`），不新造弹层方言。
/// 与其他弹层一致：**不加灰色遮罩**，只留透明点击层。
struct MotivationEditorCard: View {
    let title: String
    let placeholder: String
    /// 字数文案由调用方用 `languageStore.text(.wordCount, count)` 生成，避免在此重复格式化规则。
    let wordCountText: (Int) -> String
    let cancelLabel: String
    let saveLabel: String

    @State private var draft: String
    let onSave: (String) -> Void
    let onCancel: () -> Void

    init(
        title: String,
        placeholder: String,
        wordCountText: @escaping (Int) -> String,
        cancelLabel: String,
        saveLabel: String,
        initialText: String,
        onSave: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.placeholder = placeholder
        self.wordCountText = wordCountText
        self.cancelLabel = cancelLabel
        self.saveLabel = saveLabel
        self._draft = State(initialValue: initialText)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    private enum Metric {
        static let cardWidth: CGFloat = 286
        static let cardCornerRadius: CGFloat = 18
        static let headerHeight: CGFloat = 35
        static let footerHeight: CGFloat = 58
        /// 固定高度：多行控件是贪婪视图，用 minHeight 拦不住它吃满父层给的空间。
        static let editorHeight: CGFloat = 146
    }

    private enum Ink {
        static let cardFill = Color(red: 0.965, green: 0.957, blue: 0.941)      // #F6F4F0
        static let cardBorder = Color.black.opacity(0.08)
        static let cardShadow = Color.black.opacity(0.14)
        static let title = Color(red: 0.22, green: 0.21, blue: 0.19)            // #383631
        static let meta = Color(red: 0.50, green: 0.47, blue: 0.43)             // #80786E
        static let editorFill = Color(red: 0.992, green: 0.988, blue: 0.98).opacity(0.96)  // #FDFCFA
        static let editorBorder = Color(red: 0.882, green: 0.863, blue: 0.839).opacity(0.96)  // #E1DCD6
    }

    private var trimmed: String { MotivationStripLayout.normalizedQuote(draft) }

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Ink.title)
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(height: Metric.headerHeight)

            VStack(spacing: 6) {
                editor
                HStack {
                    Spacer(minLength: 0)
                    Text(wordCountText(trimmed.count))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Ink.meta)
                }
                .frame(height: 16)
            }
            .padding(.horizontal, 18)

            HStack(spacing: 8) {
                Button(cancelLabel, action: onCancel)
                    .buttonStyle(MotivationSecondaryButtonStyle())
                    .keyboardShortcut(.cancelAction)

                Button(saveLabel) { onSave(trimmed) }
                    .buttonStyle(MotivationPrimaryButtonStyle())
                    .disabled(trimmed.isEmpty)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 18)
            .padding(.top, 4)
            .padding(.bottom, 16)
            .frame(height: Metric.footerHeight, alignment: .bottom)
        }
        .frame(width: Metric.cardWidth)
        // 不给 minHeight/maxHeight：弹性 frame 会被父层 ZStack 撑到 maxHeight，
        // 而内部没有 Spacer 消化多余空间，多出来的高度会均分到内容上下，表现为标题上方一大片空白。
        // 编辑器本身是固定高度，卡片按内容定高即可。
        .background(
            RoundedRectangle(cornerRadius: Metric.cardCornerRadius, style: .continuous)
                .fill(Ink.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Metric.cardCornerRadius, style: .continuous)
                .stroke(Ink.cardBorder, lineWidth: 1)
        )
        .shadow(color: Ink.cardShadow, radius: 18, y: 10)
    }

    private var editor: some View {
        MotivationTextEditor(
            text: $draft,
            placeholder: placeholder,
            inset: 14,
            autofocus: true
        )
        .frame(maxWidth: .infinity)
        .frame(height: Metric.editorHeight)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Ink.editorFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Ink.editorBorder, lineWidth: 0.5)
        )
    }
}

private struct MotivationPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color(red: 0.204, green: 0.192, blue: 0.180).opacity(configuration.isPressed ? 0.85 : 1))
            )
    }
}

private struct MotivationSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Color(red: 0.365, green: 0.333, blue: 0.306))
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.92 : 1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color(red: 0.886, green: 0.859, blue: 0.824), lineWidth: 1)
            )
    }
}
