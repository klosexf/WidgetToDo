import SwiftUI

/// 高频任务名标签行：单行横向排列，放不下时两侧出现悬浮圆形箭头，点击平滑滑动（S1 方案）。
///
/// 同一组件服务两处入口：
/// - 主窗口「快速添加」行（点击直接创建任务）；
/// - 新建任务表单「常用」行（点击填入标题，可继续编辑）。
struct FrequentTaskChipRail: View {
    let label: String
    let entries: [FrequentTaskName]
    let onTapChip: (FrequentTaskName) -> Void

    @State private var contentWidth: CGFloat = 0
    @State private var viewportWidth: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var hoveredIndex: Int?

    var body: some View {
        if !entries.isEmpty {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(FrequentChipPalette.labelBar)
                        .frame(width: 3, height: 10)
                    Text(label)
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(FrequentChipPalette.label)
                }
                .fixedSize()

                railViewport
            }
        }
    }

    private var railViewport: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                        chip(entry, index: index)
                            .id(index)
                    }
                }
                .padding(.vertical, 1)
            }
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.x + geometry.contentInsets.leading
            } action: { _, offset in
                scrollOffset = offset
            }
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentSize.width
            } action: { _, width in
                contentWidth = width
            }
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear { viewportWidth = geometry.size.width }
                        .onChange(of: geometry.size.width) { _, width in
                            viewportWidth = width
                        }
                }
            )
            .overlay(alignment: .leading) {
                if canScrollLeft {
                    arrowButton(direction: .left) {
                        scrollRail(proxy, direction: .left)
                    }
                }
            }
            .overlay(alignment: .trailing) {
                if canScrollRight {
                    arrowButton(direction: .right) {
                        scrollRail(proxy, direction: .right)
                    }
                }
            }
        }
    }

    private func chip(_ entry: FrequentTaskName, index: Int) -> some View {
        Button {
            onTapChip(entry)
        } label: {
            Text(entry.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(FrequentChipPalette.chipText)
                .lineLimit(1)
                .padding(.horizontal, 11)
                .frame(height: 26)
                .background(
                    Capsule(style: .continuous)
                        .fill(hoveredIndex == index ? FrequentChipPalette.chipFillHover : FrequentChipPalette.chipFill)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.18)) {
                hoveredIndex = hovering ? index : (hoveredIndex == index ? nil : hoveredIndex)
            }
        }
    }

    private func arrowButton(direction: ArrowDirection, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: direction == .left ? "chevron.left" : "chevron.right")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(FrequentChipPalette.arrowIcon)
                .frame(width: 22, height: 22)
                .background(
                    Circle()
                        .fill(.white)
                )
                .overlay(
                    Circle()
                        .stroke(FrequentChipPalette.arrowBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .offset(x: direction == .left ? -6 : 6)
    }

    // MARK: - Scrolling

    private enum ArrowDirection {
        case left
        case right
    }

    private var canScrollLeft: Bool {
        scrollOffset > 2
    }

    private var canScrollRight: Bool {
        contentWidth > viewportWidth && scrollOffset + viewportWidth < contentWidth - 2
    }

    /// 按平均宽度估算目标索引，跳到下一屏标签。
    private func scrollRail(_ proxy: ScrollViewProxy, direction: ArrowDirection) {
        guard !entries.isEmpty, contentWidth > 0 else { return }

        let averageChipWidth = contentWidth / CGFloat(entries.count)
        guard averageChipWidth > 0 else { return }

        let step = viewportWidth * 0.8
        let rawTarget = direction == .right
            ? scrollOffset + step
            : scrollOffset - step
        let targetIndex = min(
            max(0, Int(round(rawTarget / averageChipWidth))),
            entries.count - 1
        )

        withAnimation(.easeInOut(duration: 0.25)) {
            proxy.scrollTo(targetIndex, anchor: .leading)
        }
    }
}

/// 标签行配色：淡底 chip（中性暖灰淡底、无描边、无阴影，无维度色、无频次），
/// 与主窗口（白底）和表单（暖灰底）均协调；箭头小圆钮独立配色（白底 + 描边，用于与下方 chip 分层）。
private enum FrequentChipPalette {
    static let label = Color(red: 0.639, green: 0.616, blue: 0.573)
    static let labelBar = Color(red: 0.847, green: 0.820, blue: 0.761)
    static let chipText = Color(red: 0.290, green: 0.271, blue: 0.239)
    static let chipFill = Color(red: 0.961, green: 0.949, blue: 0.922)
    static let chipFillHover = Color(red: 0.933, green: 0.914, blue: 0.867)
    static let arrowIcon = Color(red: 0.290, green: 0.271, blue: 0.239)
    static let arrowBorder = Color(red: 0.886, green: 0.859, blue: 0.824)
}
