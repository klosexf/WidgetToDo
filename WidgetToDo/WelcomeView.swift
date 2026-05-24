import SwiftUI

struct WelcomeView: View {
    let onStartConfig: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // 产品图标
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(.green)
                Image(systemName: "book.pages.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            }

            Spacer().frame(height: 24)

            // 产品名称
            Text("欢迎使用 WidgetToDo")
                .font(.system(size: 22, weight: .semibold))

            Spacer().frame(height: 12)

            // 一句话价值说明
            Text("一个常驻桌面的 Notion 小窗口")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            Spacer().frame(height: 4)

            Text("待办 · 日记 · 一目了然")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            Spacer().frame(height: 32)

            // 开始配置按钮
            Button {
                onStartConfig()
            } label: {
                HStack(spacing: 6) {
                    Text("开始配置")
                        .font(.system(size: 14, weight: .medium))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer().frame(height: 24)

            // 5 步进度点
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 8, height: 8)
                ForEach(1..<5, id: \.self) { _ in
                    Circle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 32)
    }
}

#Preview("Welcome") {
    WelcomeView(onStartConfig: {})
        .frame(width: 340, height: 560)
}
