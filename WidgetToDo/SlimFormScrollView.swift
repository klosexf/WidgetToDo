import AppKit
import SwiftUI

private enum SlimFormScrollerMetrics {
    static let thumbWidth: CGFloat = 5
    static let thumbCornerRadius: CGFloat = 2.5
    static let thumbColor = NSColor(calibratedWhite: 0.38, alpha: 0.78)
}

struct SlimFormScrollView<Content: View>: NSViewRepresentable {
    let usesContentHeight: Bool
    let contentHeightLimit: CGFloat?
    let content: Content

    init(
        usesContentHeight: Bool = false,
        contentHeightLimit: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.usesContentHeight = usesContentHeight
        self.contentHeightLimit = contentHeightLimit
        self.content = content()
    }

    func makeNSView(context: Context) -> HostingScrollView<Content> {
        HostingScrollView(
            rootView: content,
            usesContentHeight: usesContentHeight,
            contentHeightLimit: contentHeightLimit
        )
    }

    func updateNSView(_ scrollView: HostingScrollView<Content>, context: Context) {
        scrollView.update(rootView: content)
    }
}

final class SlimVerticalScroller: NSScroller {
    override class func scrollerWidth(
        for controlSize: NSControl.ControlSize,
        scrollerStyle: NSScroller.Style
    ) -> CGFloat {
        SlimFormScrollerMetrics.thumbWidth
    }

    override func drawKnobSlot(in slotRect: NSRect, highlight flag: Bool) {}

    override func drawKnob() {
        SlimFormScrollerMetrics.thumbColor.setFill()
        NSBezierPath(
            roundedRect: rect(for: .knob),
            xRadius: SlimFormScrollerMetrics.thumbCornerRadius,
            yRadius: SlimFormScrollerMetrics.thumbCornerRadius
        ).fill()
    }
}

final class HostingScrollView<Content: View>: NSScrollView {
    private let hostingView: NSHostingView<Content>
    private let usesContentHeight: Bool
    private let contentHeightLimit: CGFloat?
    private var measuredContentHeight: CGFloat = 1

    init(rootView: Content, usesContentHeight: Bool, contentHeightLimit: CGFloat?) {
        self.usesContentHeight = usesContentHeight
        self.contentHeightLimit = contentHeightLimit
        hostingView = NSHostingView(rootView: rootView)
        super.init(frame: .zero)

        drawsBackground = false
        borderType = .noBorder
        hasHorizontalScroller = false
        hasVerticalScroller = true
        autohidesScrollers = true
        scrollerStyle = .overlay
        verticalScroller = SlimVerticalScroller()

        documentView = hostingView
    }

    override var intrinsicContentSize: NSSize {
        guard usesContentHeight else { return super.intrinsicContentSize }
        return NSSize(
            width: NSView.noIntrinsicMetric,
            height: min(measuredContentHeight, contentHeightLimit ?? measuredContentHeight)
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(rootView: Content) {
        hostingView.rootView = rootView
        hostingView.invalidateIntrinsicContentSize()
        needsLayout = true
        layoutSubtreeIfNeeded()
        updateDocumentLayout()
    }

    override func layout() {
        super.layout()
        updateDocumentLayout()
    }

    private func updateDocumentLayout() {
        let documentWidth = contentView.bounds.width
        guard documentWidth > 0 else { return }

        hostingView.frame = NSRect(x: 0, y: 0, width: documentWidth, height: 1)
        hostingView.layoutSubtreeIfNeeded()
        let contentHeight = max(hostingView.fittingSize.height, 1)
        hostingView.frame.size.height = contentHeight
        updateMeasuredContentHeight(contentHeight)
        reflectScrolledClipView(contentView)
    }

    private func updateMeasuredContentHeight(_ contentHeight: CGFloat) {
        guard usesContentHeight,
              abs(measuredContentHeight - contentHeight) > 0.5
        else { return }

        measuredContentHeight = contentHeight
        invalidateIntrinsicContentSize()
    }
}
