import SwiftUI

/// 浮窗顶部的激励话术单行条：通栏、居中、宋体，超长时横向跑马灯。
///
/// 放在带 padding 的壳层之外，因此自己贴窗口上缘并自带白底；
/// 关闭时整条不渲染，不占用列表高度。
///
/// 色值与 `ContentView.swift:1090-1130` 的 `FloatingWidgetPalette` 对齐——
/// 那边是 private 枚举，跨文件取不到，这里只复制本条用到的三项。
struct MotivationStripView: View {
    /// 已归一化的单行文案；空串表示未设置。
    let quote: String
    let placeholderText: String
    let editAction: () -> Void

    @EnvironmentObject private var languageStore: LanguageStore

    @State private var containerWidth: CGFloat = 0
    @State private var textWidth: CGFloat = 0
    @State private var isHovering = false
    @State private var timeOrigin = Date()
    @State private var pauseStart: Date?

    private enum Metric {
        /// 28pt：与 chip 行（26）同一量级。条现在是内容列里的一行，
        /// 不再是窗口顶缘的冠冕，44pt 的居中空气会让它与 tab 行之间显得过空。
        static let height: CGFloat = 28
        /// 条现在位于内容列内（左右已由 shellPadding 内缩 16），自身不再加横向内边距，
        /// 使右缘编辑按钮与日期行操作图标对齐同一条垂直线。
        static let horizontalPadding: CGFloat = 0
        /// 给常驻编辑按钮预留的宽度，避免文字压在按钮下面。
        static let trailingAllowance: CGFloat = 40
    }

    private enum Ink {
        static let quote = Color(red: 0.420, green: 0.365, blue: 0.310)   // #6B5D4F
        static let placeholder = Color(red: 0.639, green: 0.616, blue: 0.573).opacity(0.75)  // #A39D92
        static let icon = Color(red: 0.47, green: 0.459, blue: 0.447)    // #787572，同顶栏图标色
    }

    /// Songti SC 只有 Regular/Bold/Black，没有 medium：
    /// 请求不存在的字重会触发 CoreText 字体替换，数字与汉字落进不同基线而错位。
    private var font: Font { .custom("Songti SC", size: 13) }
    private var isPlaceholder: Bool { quote.isEmpty }
    private var displayText: String { isPlaceholder ? placeholderText : quote }

    private var availableWidth: CGFloat {
        MotivationStripLayout.availableWidth(
            containerWidth: containerWidth,
            horizontalPadding: Metric.horizontalPadding,
            trailingAllowance: Metric.trailingAllowance
        )
    }

    private var shouldScroll: Bool {
        guard containerWidth > 0, textWidth > 0 else { return false }
        return MotivationStripLayout.shouldScroll(
            textWidth: textWidth,
            availableWidth: availableWidth,
            gap: MotivationStripLayout.gap
        )
    }

    var body: some View {
        Group {
            if shouldScroll {
                scrollingText
            } else {
                staticText
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Metric.height)
        .overlay(alignment: .trailing) {
            editButton
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: editAction)
        .onHover { hovering in
            isHovering = hovering
            // 暂停期间的时间不计入位移，恢复时不跳帧
            if hovering {
                pauseStart = Date()
            } else if let pausedAt = pauseStart {
                timeOrigin.addTimeInterval(Date().timeIntervalSince(pausedAt))
                pauseStart = nil
            }
        }
        .background(
            ZStack {
                Color.clear
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { containerWidth = $0 }

                // 必须用 fixedSize 探针量文字的「固有宽度」。
                // 直接量布局中的 Text 只会得到被容器截断后的宽度，
                // 跑马灯的位移距离就会远小于文字真实长度，表现为只滚出开头一小截。
                // 量完立刻塌成 0×0 并裁掉：探针若参与布局，ZStack 会取它的固有宽度，
                // 把 containerWidth 污染成文字宽度，整条被撑到上千 pt。
                Text(displayText)
                    .font(font)
                    .fixedSize(horizontal: true, vertical: false)
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { textWidth = $0 }
                    .frame(width: 0, height: 0)
                    .clipped()
            }
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { editAction() }
    }

    // MARK: - Pieces

    private var staticText: some View {
        Text(displayText)
            .font(font)
            .foregroundStyle(isPlaceholder ? Ink.placeholder : Ink.quote)
            .lineLimit(1)
            .padding(.horizontal, Metric.horizontalPadding)
    }

    private var scrollingText: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !shouldScroll || isHovering)) { context in
            let cycle = textWidth + MotivationStripLayout.gap
            let duration = MotivationStripLayout.scrollDuration(textWidth: textWidth, gap: MotivationStripLayout.gap)
            let elapsed = max(0, context.date.timeIntervalSince(timeOrigin))
            let progress = duration > 0
                ? (elapsed.truncatingRemainder(dividingBy: duration)) / duration
                : 0

            HStack(spacing: MotivationStripLayout.gap) {
                Text(displayText).font(font).foregroundStyle(Ink.quote)
                Text(displayText).font(font).foregroundStyle(Ink.quote).accessibilityHidden(true)
            }
            .fixedSize()
            .offset(x: -cycle * progress)
            .padding(.horizontal, Metric.horizontalPadding)
            .frame(width: max(0, containerWidth), alignment: .leading)
            .clipped()
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 10 / max(containerWidth, 1)),
                        .init(color: .black, location: 1 - 14 / max(containerWidth, 1)),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
    }

    private var editButton: some View {
        Button(action: editAction) {
            Image(systemName: "pencil")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Ink.icon)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(red: 0.996, green: 0.992, blue: 0.984).opacity(0.96))  // 同任务行 ⋯ 按钮
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(red: 0.918, green: 0.898, blue: 0.878).opacity(0.95), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .padding(.trailing, 12)
        // 只在鼠标移入显示区域时出现。按钮槽位常驻预留 40px，避免浮现时文字宽度突变。
        .opacity(isHovering ? 1 : 0)
        .animation(.easeInOut(duration: 0.18), value: isHovering)
        .accessibilityLabel(languageStore.text(.motivationEditorTitle))
    }
}
