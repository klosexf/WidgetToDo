import AppKit
import SwiftUI

/// Shared appearance for the floating widget and its forms.
/// Retains WidgetToDo's warm palette and existing semantic state colors.
enum WidgetTheme {
    static let shell = Color(red: 0.996, green: 0.992, blue: 0.984).opacity(0.84)
    static let content = Color(red: 0.992, green: 0.988, blue: 0.980)
    static let control = Color(red: 0.957, green: 0.945, blue: 0.929)
    static let hover = Color(red: 0.569, green: 0.420, blue: 0.322).opacity(0.055)
    static let border = Color(red: 0.55, green: 0.50, blue: 0.44).opacity(0.14)
    static let text = Color(red: 0.176, green: 0.169, blue: 0.161)
    static let secondary = Color(red: 0.545, green: 0.522, blue: 0.494)
    static let accent = Color(red: 0.569, green: 0.420, blue: 0.322)
    static let ringAccent = Color(red: 0.631, green: 0.486, blue: 0.349)
    static let primaryAction = Color(red: 0.204, green: 0.192, blue: 0.180)
    static let journalAccent = Color(red: 0.478, green: 0.612, blue: 0.776)
    static let success = Color(red: 0.22, green: 0.51, blue: 0.31)
}

/// A drawing-only backing: event handling remains with SwiftUI and the panel.
struct WidgetWindowMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = PassiveVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

private final class PassiveVisualEffectView: NSVisualEffectView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
