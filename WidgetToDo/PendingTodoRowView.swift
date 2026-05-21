import SwiftUI

struct PendingTodoRowView: View {
    let item: PendingTaskItem
    let showFailure: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("⏳")
                .font(.system(size: 16))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 14))
                    .foregroundStyle(.primary.opacity(0.5))
                HStack(spacing: 8) {
                    if let priority = item.priority {
                        Text(priority)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.12), in: Capsule())
                    }

                    Text(item.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .frame(height: 36)
        .background(showFailure ? Color.red.opacity(0.2) : Color.clear)
        .animation(.easeInOut(duration: 0.3), value: showFailure)
    }
}
