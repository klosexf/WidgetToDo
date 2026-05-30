import SwiftUI

private enum WelcomeMetrics {
    static let horizontalPadding: CGFloat = 14
    static let topPadding: CGFloat = 12
    static let headerHeight: CGFloat = 30
    static let closeButtonSize: CGFloat = 24
    static let closeButtonCornerRadius: CGFloat = 6
    static let illustrationHeight: CGFloat = 186
    static let illustrationTopPadding: CGFloat = 6
    static let illustrationBottomSpacing: CGFloat = 12
    static let illustrationScale: CGFloat = 1.34
    static let illustrationOffsetY: CGFloat = 8
    static let titleBottomSpacing: CGFloat = 8
    static let subtitleBottomSpacing: CGFloat = 2
    static let featuresBottomSpacing: CGFloat = 20
    static let buttonMinWidth: CGFloat = 170
    static let buttonHorizontalPadding: CGFloat = 28
    static let buttonVerticalPadding: CGFloat = 10
    static let buttonCornerRadius: CGFloat = 8
    static let ctaArrowHoverOffset: CGFloat = 3
}

private struct WelcomeCTAButtonStyle: ButtonStyle {
    let isHovered: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, WelcomeMetrics.buttonHorizontalPadding)
            .padding(.vertical, WelcomeMetrics.buttonVerticalPadding)
            .background(
                RoundedRectangle(cornerRadius: WelcomeMetrics.buttonCornerRadius, style: .continuous)
                    .fill(Color(red: 45 / 255, green: 45 / 255, blue: 45 / 255))
            )
            .shadow(
                color: .black.opacity(isHovered ? 0.22 : 0.16),
                radius: isHovered ? 16 : 10,
                x: 0,
                y: isHovered ? 10 : 6
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .offset(y: isHovered && !configuration.isPressed ? -1 : 0)
            .animation(.easeOut(duration: 0.18), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.22), value: isHovered)
    }
}

struct WelcomeView: View {
    let onStartConfig: () -> Void
    let onClose: () -> Void

    @State private var isAppeared = false
    @State private var isButtonHovered = false
    @State private var isCloseButtonHovered = false

    var body: some View {
        VStack(spacing: 0) {
            headerPlaceholder
                .frame(height: WelcomeMetrics.headerHeight)
                .padding(.top, WelcomeMetrics.topPadding)

            illustrationViewport
                .padding(.top, WelcomeMetrics.illustrationTopPadding)
                .padding(.bottom, WelcomeMetrics.illustrationBottomSpacing)

            titleView
                .padding(.bottom, WelcomeMetrics.titleBottomSpacing)

            subtitleView
                .padding(.bottom, WelcomeMetrics.subtitleBottomSpacing)

            featuresView
                .padding(.bottom, WelcomeMetrics.featuresBottomSpacing)

            Button {
                onStartConfig()
            } label: {
                ctaLabel
                    .frame(minWidth: WelcomeMetrics.buttonMinWidth)
            }
            .buttonStyle(WelcomeCTAButtonStyle(isHovered: isButtonHovered))
            .onHover { hovering in
                isButtonHovered = hovering
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, WelcomeMetrics.horizontalPadding)
        .opacity(isAppeared ? 1 : 0)
        .scaleEffect(isAppeared ? 1 : 0.965)
        .offset(y: isAppeared ? 0 : 16)
        .animation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.48), value: isAppeared)
        .onAppear {
            guard !isAppeared else { return }
            isAppeared = true
        }
    }

    private var headerPlaceholder: some View {
        Color.clear
            .overlay(alignment: .trailing) {
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(isCloseButtonHovered ? 0.56 : 0.42))
                        .frame(width: WelcomeMetrics.closeButtonSize, height: WelcomeMetrics.closeButtonSize)
                        .background(
                            RoundedRectangle(cornerRadius: WelcomeMetrics.closeButtonCornerRadius, style: .continuous)
                                .fill(Color.black.opacity(isCloseButtonHovered ? 0.06 : 0.04))
                        )
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    isCloseButtonHovered = hovering
                }
                .accessibilityLabel("关闭")
            }
            .frame(maxWidth: .infinity)
    }

    private var illustrationViewport: some View {
        ZStack {
            Image("WelcomeIllustration")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scaleEffect(WelcomeMetrics.illustrationScale)
                .offset(y: WelcomeMetrics.illustrationOffsetY)
        }
        .frame(maxWidth: .infinity)
        .frame(height: WelcomeMetrics.illustrationHeight)
        .clipped()
        .accessibilityHidden(true)
    }

    private var titleView: some View {
        Text("欢迎使用 WidgetToDo")
            .font(.system(size: 24, weight: .bold))
            .tracking(-0.25)
            .foregroundStyle(Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255))
            .multilineTextAlignment(.center)
    }

    private var subtitleView: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("一个常驻桌面的")
                .foregroundStyle(Color(red: 107 / 255, green: 107 / 255, blue: 107 / 255))

            Text("Notion")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color(red: 245 / 255, green: 245 / 255, blue: 245 / 255))
                )

            Text("小窗口")
                .foregroundStyle(Color(red: 107 / 255, green: 107 / 255, blue: 107 / 255))
        }
        .font(.system(size: 14))
        .frame(maxWidth: .infinity)
    }

    private var featuresView: some View {
        Text("待办 · 日记 · 一目了然")
            .font(.system(size: 14, weight: .medium))
            .tracking(0.5)
            .foregroundStyle(Color(red: 107 / 255, green: 107 / 255, blue: 107 / 255))
            .multilineTextAlignment(.center)
    }

    private var ctaLabel: some View {
        HStack(spacing: 9) {
            Image(systemName: "book.pages.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)

            Text("开始配置")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)

            Image(systemName: "arrow.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .offset(x: isButtonHovered ? WelcomeMetrics.ctaArrowHoverOffset : 0)
                .animation(.easeOut(duration: 0.2), value: isButtonHovered)
        }
    }

}

#if canImport(PreviewsMacros)
#Preview {
    WelcomeView(onStartConfig: {}, onClose: {})
        .frame(width: 340, height: 460)
}
#endif
