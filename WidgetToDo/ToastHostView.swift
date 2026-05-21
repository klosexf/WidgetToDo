import SwiftUI

enum ToastKind: Equatable {
    case success
    case taskCreateFailed
}

struct ToastItem: Equatable, Identifiable {
    let id = UUID()
    let kind: ToastKind
    let message: String
}

struct ToastHostView: View {
    let toast: ToastItem?

    var body: some View {
        Group {
            if let toast {
                Text(toast.message)
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .frame(width: 280, height: 56)
                    .background(backgroundKind(for: toast.kind))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: toast)
    }

    private func backgroundKind(for kind: ToastKind) -> Color {
        switch kind {
        case .success:
            Color.green.opacity(0.9)
        case .taskCreateFailed:
            Color.red.opacity(0.9)
        }
    }
}
