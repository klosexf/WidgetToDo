import SwiftUI

enum NewTaskFormMetrics {
    static let cardWidth: CGFloat = 286
    static let cardMinHeight: CGFloat = 242
    static let cardMaxHeight: CGFloat = 376
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

enum TaskChoicePalette {
    static let unset = NewTaskFormPalette.meta

    static func dot(for option: NotionSelectOption?) -> Color {
        switch option?.color {
        case .gray: return Color(red: 0.54, green: 0.54, blue: 0.52)
        case .brown: return Color(red: 0.57, green: 0.42, blue: 0.32)
        case .orange: return Color(red: 0.84, green: 0.43, blue: 0.10)
        case .yellow: return Color(red: 0.76, green: 0.60, blue: 0.08)
        case .green: return Color(red: 0.20, green: 0.55, blue: 0.31)
        case .blue: return Color(red: 0.20, green: 0.48, blue: 0.78)
        case .purple: return Color(red: 0.49, green: 0.32, blue: 0.74)
        case .pink: return Color(red: 0.78, green: 0.30, blue: 0.53)
        case .red: return Color(red: 0.78, green: 0.25, blue: 0.22)
        case .default, .none: return unset
        }
    }
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
        SlimFormScrollView {
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

            if let choiceField = viewModel.choiceField {
                TaskChoicePicker(field: choiceField, selection: $viewModel.priority)
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
        }
        .frame(width: NewTaskFormMetrics.cardWidth)
        .frame(minHeight: NewTaskFormMetrics.cardMinHeight, maxHeight: NewTaskFormMetrics.cardMaxHeight)
        .background(
            RoundedRectangle(cornerRadius: NewTaskFormMetrics.cardCornerRadius, style: .continuous)
                .fill(NewTaskFormPalette.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: NewTaskFormMetrics.cardCornerRadius, style: .continuous)
                .stroke(NewTaskFormPalette.cardBorder, lineWidth: 1)
        )
        .shadow(color: NewTaskFormPalette.cardShadow, radius: 18, y: 10)
        .onSubmit {
            viewModel.submit()
        }
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

private struct TaskChoicePicker: View {
    let field: TaskChoiceField
    @Binding var selection: String?
    @State private var searchText = ""
    @State private var isOptionsPresented = false
    @FocusState private var isSearchFocused: Bool

    private var selectedOption: NotionSelectOption? {
        field.options.first { $0.name == selection }
    }

    private var filteredOptions: [NotionSelectOption] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return field.options }
        return field.options.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    private var optionsListHeight: CGFloat {
        min(CGFloat(filteredOptions.count) * 30, 120)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            NewTaskFieldLabel(text: field.name)

            HStack(spacing: 0) {
                    Group {
                        if let selectedOption, !isOptionsPresented {
                            Circle()
                                .fill(TaskChoicePalette.dot(for: selectedOption))
                                .frame(width: 8, height: 8)
                        } else {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(NewTaskFormPalette.meta)
                        }
                    }
                    .frame(width: 32)

                    TextField("搜索或选择类型", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(NewTaskFormPalette.title)
                        .focused($isSearchFocused)
                        .simultaneousGesture(TapGesture().onEnded {
                            presentOptions()
                        })

                    Button {
                        toggleOptions()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(NewTaskFormPalette.meta)
                            .frame(width: 34, height: NewTaskFormMetrics.fieldHeight)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(NewTaskFormPalette.fieldBorder)
                            .frame(width: 1)
                            .padding(.vertical, 7)
                    }
            }
            .frame(maxWidth: .infinity)
            .frame(height: NewTaskFormMetrics.fieldHeight)
            .background(
                RoundedRectangle(cornerRadius: NewTaskFormMetrics.fieldCornerRadius, style: .continuous)
                    .fill(NewTaskFormPalette.fieldFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: NewTaskFormMetrics.fieldCornerRadius, style: .continuous)
                    .stroke(typePickerBorderColor(), lineWidth: 1)
            )

            if isOptionsPresented {
                typeOptionsMenu
            }
        }
        .onAppear {
            searchText = selection ?? ""
        }
        .onChange(of: selection) { _, newSelection in
            guard !isOptionsPresented else { return }
            searchText = newSelection ?? ""
        }
    }

    private var typeOptionsMenu: some View {
        VStack(spacing: 2) {
            Button {
                clearSelection()
            } label: {
                typeOptionRow(title: "未选择", option: nil)
            }
            .buttonStyle(.plain)

            if filteredOptions.isEmpty {
                Text("没有匹配的类型")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(NewTaskFormPalette.meta)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 2) {
                        ForEach(filteredOptions, id: \.name) { option in
                            Button {
                                select(option)
                            } label: {
                                typeOptionRow(title: option.name, option: option)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(height: optionsListHeight)
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: NewTaskFormMetrics.fieldCornerRadius, style: .continuous)
                .fill(NewTaskFormPalette.fieldFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: NewTaskFormMetrics.fieldCornerRadius, style: .continuous)
                .stroke(NewTaskFormPalette.fieldBorder, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func typeOptionRow(title: String, option: NotionSelectOption?) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(TaskChoicePalette.dot(for: option))
                .frame(width: 8, height: 8)
            Text(title)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(NewTaskFormPalette.title)
            Spacer()
            if selection == option?.name {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(NewTaskFormPalette.focusBorder)
            }
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .frame(height: 28)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(selection == option?.name ? NewTaskFormPalette.focusBorder.opacity(0.10) : Color.clear)
        )
    }

    private func presentOptions() {
        guard !isOptionsPresented else { return }
        searchText = ""
        isOptionsPresented = true
    }

    private func toggleOptions() {
        if isOptionsPresented {
            dismissOptions()
        } else {
            presentOptions()
            isSearchFocused = true
        }
    }

    private func dismissOptions() {
        isOptionsPresented = false
        isSearchFocused = false
        searchText = selection ?? ""
    }

    private func clearSelection() {
        selection = nil
        searchText = ""
        isOptionsPresented = false
        isSearchFocused = false
    }

    private func select(_ option: NotionSelectOption) {
        selection = option.name
        searchText = option.name
        isOptionsPresented = false
        isSearchFocused = false
    }

    private func typePickerBorderColor() -> Color {
        isSearchFocused || isOptionsPresented
            ? NewTaskFormPalette.focusBorder
            : NewTaskFormPalette.fieldBorder
    }
}
