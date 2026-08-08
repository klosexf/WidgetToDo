import SwiftUI

enum NewTaskFormMetrics {
    static let cardWidth: CGFloat = 286
    static let cardMinHeight: CGFloat = 242
    static let cardCornerRadius: CGFloat = 18
    static let verticalSpacing: CGFloat = 14
    static let fieldCornerRadius: CGFloat = 10
    static let fieldHeight: CGFloat = 34
    static let contentPadding = EdgeInsets(top: 18, leading: 18, bottom: 16, trailing: 18)
}

enum NewTaskFormPalette {
    static let cardFill = Color(red: 0.965, green: 0.957, blue: 0.941)
    static let cardBorder = Color.black.opacity(0.08)
    static let cardShadow = Color.black.opacity(0.14)
    static let title = Color(red: 0.22, green: 0.21, blue: 0.19)
    static let meta = Color(red: 0.50, green: 0.47, blue: 0.43)
    static let fieldFill = Color.white
    static let fieldBorder = Color.black.opacity(0.10)
    static let validationBorder = Color.red.opacity(0.85)
    static let focusBorder = Color(red: 0.35, green: 0.61, blue: 0.93)
    static let accent = Color.accentColor
    static let primaryButtonFill = Color(red: 0.204, green: 0.192, blue: 0.180)
    static let primaryButtonText = Color.white
    static let secondaryButtonFill = Color.white
    static let secondaryButtonBorder = Color(red: 0.886, green: 0.859, blue: 0.824)
    static let secondaryButtonText = Color(red: 0.365, green: 0.333, blue: 0.306)
}

struct NewTaskPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(NewTaskFormPalette.primaryButtonText)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(NewTaskFormPalette.primaryButtonFill.opacity(configuration.isPressed ? 0.85 : 1))
            )
    }
}

struct NewTaskSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(NewTaskFormPalette.secondaryButtonText)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(NewTaskFormPalette.secondaryButtonFill.opacity(configuration.isPressed ? 0.92 : 1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(NewTaskFormPalette.secondaryButtonBorder, lineWidth: 1)
            )
    }
}

private struct NewTaskFieldLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(NewTaskFormPalette.title)
    }
}

private struct PlainDatePicker: NSViewRepresentable {
    @Binding var date: Date

    func makeNSView(context: Context) -> NSDatePicker {
        let picker = NSDatePicker()
        picker.datePickerStyle = .textField
        picker.drawsBackground = false
        picker.isBezeled = false
        picker.isBordered = false
        picker.datePickerElements = .yearMonthDay
        picker.target = context.coordinator
        picker.action = #selector(Coordinator.dateChanged(_:))
        picker.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        picker.textColor = NSColor(NewTaskFormPalette.title)
        return picker
    }

    func updateNSView(_ nsView: NSDatePicker, context: Context) {
        nsView.dateValue = date
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(date: $date)
    }

    final class Coordinator: NSObject {
        @Binding var date: Date

        init(date: Binding<Date>) {
            self._date = date
        }

        @objc func dateChanged(_ sender: NSDatePicker) {
            date = sender.dateValue
        }
    }
}

struct NewTaskFormCard: View {
    @ObservedObject var viewModel: NewTaskViewModel
    @EnvironmentObject private var languageStore: LanguageStore
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isEstimatedMinutesFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: NewTaskFormMetrics.verticalSpacing) {
            Text(languageStore.text(.newTask))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(NewTaskFormPalette.title)
                .frame(maxWidth: .infinity, alignment: .center)

            VStack(alignment: .leading, spacing: 6) {
                NewTaskFieldLabel(text: languageStore.text(.taskLabel))

                TextField(languageStore.text(.taskLabel), text: $viewModel.title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(NewTaskFormPalette.title)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity)
                    .frame(height: NewTaskFormMetrics.fieldHeight)
                    .background(
                        RoundedRectangle(cornerRadius: NewTaskFormMetrics.fieldCornerRadius, style: .continuous)
                            .fill(NewTaskFormPalette.fieldFill)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: NewTaskFormMetrics.fieldCornerRadius, style: .continuous)
                            .stroke(
                                titleBorderColor(),
                                lineWidth: viewModel.formState == .validationFailed ? 1.5 : 1
                            )
                    )
                    .modifier(ShakeEffect(animatableData: viewModel.shakeAttempts))
                    .focused($isTitleFocused)
                    .onAppear {
                        isTitleFocused = true
                    }

                if viewModel.formState == .validationFailed {
                    Text(languageStore.text(.taskTitleRequired))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                NewTaskFieldLabel(text: languageStore.text(.dateLabel))

                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(NewTaskFormPalette.meta)
                        .frame(width: 18)

                    PlainDatePicker(date: $viewModel.taskDate)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 12)
                .frame(height: NewTaskFormMetrics.fieldHeight)
                .background(
                    RoundedRectangle(cornerRadius: NewTaskFormMetrics.fieldCornerRadius, style: .continuous)
                        .fill(NewTaskFormPalette.fieldFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: NewTaskFormMetrics.fieldCornerRadius, style: .continuous)
                        .stroke(NewTaskFormPalette.fieldBorder, lineWidth: 1)
                )
            }

            VStack(alignment: .leading, spacing: 6) {
                NewTaskFieldLabel(text: languageStore.text(.estimatedMinutesLabel))

                HStack(spacing: 0) {
                    TextField(languageStore.text(.estimatedMinutesLabel), text: $viewModel.estimatedMinutesText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(NewTaskFormPalette.title)

                    Spacer()

                    Text(languageStore.text(.minutesLabel))
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(NewTaskFormPalette.meta)
                }
                .padding(.leading, 12)
                .padding(.trailing, 12)
                .frame(maxWidth: .infinity)
                .frame(height: NewTaskFormMetrics.fieldHeight)
                .background(
                    RoundedRectangle(cornerRadius: NewTaskFormMetrics.fieldCornerRadius, style: .continuous)
                        .fill(NewTaskFormPalette.fieldFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: NewTaskFormMetrics.fieldCornerRadius, style: .continuous)
                        .stroke(
                            estimatedMinutesBorderColor(),
                            lineWidth: viewModel.estimatedMinutesError == nil ? 1 : 1.5
                        )
                )
                .focused($isEstimatedMinutesFocused)

                if let estimatedMinutesError = viewModel.estimatedMinutesError {
                    Text(languageStore.text(estimatedMinutesError))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            HStack(spacing: 8) {
                Button(languageStore.text(.cancel)) {
                    viewModel.dismissForm()
                }
                .buttonStyle(NewTaskSecondaryButtonStyle())

                Button(languageStore.text(.create)) {
                    viewModel.submit()
                }
                .buttonStyle(NewTaskPrimaryButtonStyle())
            }
            .padding(.top, 4)
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

    private func titleBorderColor() -> Color {
        if viewModel.formState == .validationFailed {
            return NewTaskFormPalette.validationBorder
        }
        if isTitleFocused {
            return NewTaskFormPalette.focusBorder
        }
        return NewTaskFormPalette.fieldBorder
    }

    private func estimatedMinutesBorderColor() -> Color {
        if viewModel.estimatedMinutesError != nil {
            return NewTaskFormPalette.validationBorder
        }
        if isEstimatedMinutesFocused {
            return NewTaskFormPalette.focusBorder
        }
        return NewTaskFormPalette.fieldBorder
    }
}
