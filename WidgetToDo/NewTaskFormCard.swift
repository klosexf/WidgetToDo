import SwiftUI

private enum NewTaskFormMetrics {
    static let cardWidth: CGFloat = 286
    static let cardMinHeight: CGFloat = 242
    static let cardCornerRadius: CGFloat = 18
    static let verticalSpacing: CGFloat = 14
    static let fieldCornerRadius: CGFloat = 12
    static let fieldHeight: CGFloat = 42
    static let contentPadding = EdgeInsets(top: 18, leading: 18, bottom: 16, trailing: 18)
}

private enum NewTaskFormPalette {
    static let cardFill = Color(red: 0.965, green: 0.957, blue: 0.941)
    static let cardBorder = Color.black.opacity(0.08)
    static let cardShadow = Color.black.opacity(0.14)
    static let title = Color(red: 0.22, green: 0.21, blue: 0.19)
    static let meta = Color(red: 0.50, green: 0.47, blue: 0.43)
    static let fieldFill = Color.white.opacity(0.78)
    static let fieldBorder = Color.black.opacity(0.10)
    static let validationBorder = Color.red.opacity(0.85)
    static let accent = Color.accentColor
}

private struct NewTaskFormTrackingModifier: ViewModifier {
    let value: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 13.0, *) {
            content.tracking(value)
        } else {
            content
        }
    }
}

struct NewTaskFormCard: View {
    @ObservedObject var viewModel: NewTaskViewModel
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: NewTaskFormMetrics.verticalSpacing) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(NewTaskFormPalette.meta)
                    .frame(width: 20, height: 20)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.72))
                    )

                Text("新建任务")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(NewTaskFormPalette.title)
                    .modifier(NewTaskFormTrackingModifier(value: -0.16))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            TextField("标题(必填)", text: $viewModel.title)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(NewTaskFormPalette.title)
                .padding(.horizontal, 12)
                .frame(height: NewTaskFormMetrics.fieldHeight)
                .background(
                    RoundedRectangle(cornerRadius: NewTaskFormMetrics.fieldCornerRadius, style: .continuous)
                        .fill(NewTaskFormPalette.fieldFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: NewTaskFormMetrics.fieldCornerRadius, style: .continuous)
                        .stroke(
                            viewModel.formState == .validationFailed
                                ? NewTaskFormPalette.validationBorder
                                : NewTaskFormPalette.fieldBorder,
                            lineWidth: viewModel.formState == .validationFailed ? 1.5 : 1
                        )
                )
                .modifier(ShakeEffect(animatableData: viewModel.shakeAttempts))
                .focused($isTitleFocused)
                .onAppear {
                    isTitleFocused = true
                }

            if viewModel.formState == .validationFailed {
                Text("标题不能为空")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(NewTaskFormPalette.meta)
                    .frame(width: 18)

                DatePicker("", selection: $viewModel.taskDate, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                TextField("预计时长（分钟，可选）", text: $viewModel.estimatedMinutesText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(NewTaskFormPalette.title)
                    .padding(.horizontal, 12)
                    .frame(height: NewTaskFormMetrics.fieldHeight)
                    .background(
                        RoundedRectangle(cornerRadius: NewTaskFormMetrics.fieldCornerRadius, style: .continuous)
                            .fill(NewTaskFormPalette.fieldFill)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: NewTaskFormMetrics.fieldCornerRadius, style: .continuous)
                            .stroke(
                                viewModel.estimatedMinutesError == nil
                                    ? NewTaskFormPalette.fieldBorder
                                    : NewTaskFormPalette.validationBorder,
                                lineWidth: viewModel.estimatedMinutesError == nil ? 1 : 1.5
                            )
                    )

                if let estimatedMinutesError = viewModel.estimatedMinutesError {
                    Text(estimatedMinutesError)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            HStack {
                Button("Esc 取消") {
                    viewModel.dismissForm()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(NewTaskFormPalette.meta)

                Spacer()

                Button("Enter 创建") {
                    viewModel.submit()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(NewTaskFormPalette.accent)
            }
        }
        .padding(NewTaskFormMetrics.contentPadding)
        .frame(width: NewTaskFormMetrics.cardWidth)
        .frame(minHeight: NewTaskFormMetrics.cardMinHeight)
        .background(
            RoundedRectangle(cornerRadius: NewTaskFormMetrics.cardCornerRadius, style: .continuous)
                .fill(NewTaskFormPalette.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: NewTaskFormMetrics.cardCornerRadius, style: .continuous)
                .stroke(NewTaskFormPalette.cardBorder, lineWidth: 1)
        )
        .shadow(color: NewTaskFormPalette.cardShadow, radius: 18, y: 10)
    }
}
