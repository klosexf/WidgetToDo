import AppKit
import SwiftUI

/// 多行编辑控件，占位文案由文本视图自己绘制。
///
/// 不用「SwiftUI Text 叠一层假占位 + TextEditor 当输入」的写法：
/// 两者的内缩是两套独立数值，光标和占位必然错位，换字号或换语言还会再错。
/// 这里占位与光标都以 `textContainerInset` 为原点，对齐由构造保证。
struct MotivationTextEditor: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    var fontSize: CGFloat = 13
    var lineSpacing: CGFloat = 6
    var inset: CGFloat = 14
    var autofocus: Bool = false

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = MotivationPlaceholderTextView()

        textView.delegate = context.coordinator
        textView.font = .systemFont(ofSize: fontSize)
        textView.textColor = NSColor(calibratedRed: 0.149, green: 0.145, blue: 0.141, alpha: 1)
        textView.insertionPointColor = NSColor(calibratedRed: 0.631, green: 0.486, blue: 0.349, alpha: 1)
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.allowsUndo = true
        textView.placeholderString = placeholder
        textView.textContainerInset = NSSize(width: inset, height: inset)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.typingAttributes[.paragraphStyle] = Self.paragraphStyle(fontSize: fontSize, lineSpacing: lineSpacing)

        scrollView.documentView = textView
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.automaticallyAdjustsContentInsets = false

        context.coordinator.textView = textView

        if autofocus {
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
            }
        }
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? MotivationPlaceholderTextView else { return }
        textView.placeholderString = placeholder
        if textView.string != text {
            textView.string = text
            textView.needsDisplay = true
        }
    }

    static func paragraphStyle(fontSize: CGFloat, lineSpacing: CGFloat) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = lineSpacing
        return style
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        weak var textView: NSTextView?

        init(text: Binding<String>) {
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            text.wrappedValue = textView.string
            textView.needsDisplay = true
        }
    }
}

private final class MotivationPlaceholderTextView: NSTextView {
    var placeholderString: String = "" {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard string.isEmpty, !placeholderString.isEmpty else { return }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font ?? NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor(calibratedWhite: 0.604, alpha: 1),
            .paragraphStyle: (typingAttributes[.paragraphStyle] as? NSParagraphStyle) ?? NSParagraphStyle.default
        ]
        let rect = NSRect(
            x: textContainerInset.width,
            y: textContainerInset.height,
            width: textContainer?.size.width ?? bounds.width - textContainerInset.width * 2,
            height: bounds.height - textContainerInset.height
        )
        placeholderString.draw(in: rect, withAttributes: attributes)
    }
}
