import SwiftUI

// MARK: - Pomodoro Palette
// Strictly mirrors the CSS token values in WidgetToDo-Welcome-Modal.html
// (.pomo-* classes) so the Pomodoro dialogs match the approved prototype.
private enum PomodoroPalette {
    // Focus card
    static let focusCardBg = Color(red: 0.992, green: 0.984, blue: 0.976)        // #fdfbf9
    static let focusCardBorder = Color(red: 0.882, green: 0.863, blue: 0.839)    // #e1dcd6
    static let ringFill = Color(red: 0.631, green: 0.486, blue: 0.349)            // #a17c59
    static let ringTrack = Color(red: 0.933, green: 0.894, blue: 0.847)           // #eee4d8
    static let ringInnerBg = Color(red: 0.992, green: 0.984, blue: 0.976)         // #fdfbf9
    static let ringTextColor = Color(red: 0.463, green: 0.345, blue: 0.216)       // #765837
    static let focusTitle = Color(red: 0.176, green: 0.176, blue: 0.176)          // #2d2d2d
    static let focusMeta = Color(red: 0.545, green: 0.510, blue: 0.471)           // #8b8278
    static let focusActionBorder = Color(red: 0.898, green: 0.867, blue: 0.831)   // #e5ddd4
    static let focusActionBg = Color(red: 1.0, green: 0.996, blue: 0.980)          // #fffefa
    static let focusActionText = Color(red: 0.369, green: 0.337, blue: 0.306)      // #5e564e
    static let focusCompleteBorder = Color(red: 0.725, green: 0.875, blue: 0.733)  // #b9dfbb
    static let focusCompleteBg = Color(red: 0.918, green: 0.965, blue: 0.906)      // #eaf6e7
    static let focusCompleteText = Color(red: 0.271, green: 0.545, blue: 0.286)   // #458b49
    static let focusDangerHoverBg = Color(red: 1.0, green: 0.941, blue: 0.929)    // #fff0ed
    static let focusDangerHoverText = Color(red: 0.733, green: 0.310, blue: 0.278)  // #bb4f47

    // Scrim + dialog shell
    static let scrimBg = Color(red: 0.153, green: 0.133, blue: 0.114).opacity(0.26) // rgba(39,34,29,.26)
    static let dialogBg = Color(red: 1.0, green: 0.996, blue: 0.980).opacity(0.98) // rgba(255,254,250,.98)
    static let dialogBorder = Color(red: 0.863, green: 0.835, blue: 0.800).opacity(0.98) // rgba(220,213,204,.98)
    static let dialogShadow = Color(red: 0.165, green: 0.137, blue: 0.110).opacity(0.20) // rgba(42,35,28,.2)

    // Dialog text
    static let kickerText = Color(red: 0.176, green: 0.176, blue: 0.176)          // #2d2d2d
    static let bodyText = Color(red: 0.459, green: 0.427, blue: 0.396)            // #756d65
    static let startBodyText = Color(red: 0.424, green: 0.392, blue: 0.361)       // #6c645c
    static let successBodyText = Color(red: 0.373, green: 0.345, blue: 0.310)     // #5f584f
    static let hintText = Color(red: 0.557, green: 0.525, blue: 0.494)            // #8e867e

    // Duration picker
    static let fieldLabel = Color(red: 0.373, green: 0.345, blue: 0.310)          // #5f584f
    static let optionBorder = Color(red: 0.863, green: 0.835, blue: 0.804)        // #dcd5cd
    static let optionBg = Color.white                                              // #fff
    static let optionText = Color(red: 0.247, green: 0.227, blue: 0.208)          // #3f3a35
    static let optionHoverBg = Color(red: 0.965, green: 0.949, blue: 0.929)       // #f6f2ed
    static let optionSelectedBorder = Color(red: 0.631, green: 0.486, blue: 0.349) // #a17c59
    static let optionSelectedBg = Color(red: 0.957, green: 0.933, blue: 0.902)   // #f4eee6
    static let optionSelectedText = Color(red: 0.369, green: 0.271, blue: 0.184)  // #5e452f
    static let customBorder = Color(red: 0.863, green: 0.835, blue: 0.804)        // #dcd5cd
    static let customBg = Color.white                                              // #fff
    static let customText = Color(red: 0.455, green: 0.420, blue: 0.384)          // #746b62
    static let customInputText = Color(red: 0.220, green: 0.200, blue: 0.184)     // #38332f
    static let customPlaceholder = Color(red: 0.604, green: 0.573, blue: 0.537)   // #9a9289
    static let customDivider = Color(red: 0.914, green: 0.894, blue: 0.867)       // #e9e4dd
    static let customUnitText = Color(red: 0.412, green: 0.381, blue: 0.349)     // #696159
    static let customFocusedBorder = Color(red: 0.725, green: 0.671, blue: 0.612) // #b9ab9c
    static let customFocusRing = Color(red: 0.631, green: 0.486, blue: 0.349).opacity(0.12) // rgba(161,124,89,.12)
    static let durationErrorText = Color(red: 0.753, green: 0.353, blue: 0.318)   // #c05a51

    // Buttons
    static let primaryBtnBg = Color(red: 0.204, green: 0.192, blue: 0.180)         // #34312e
    static let primaryBtnHoverBg = Color(red: 0.129, green: 0.122, blue: 0.114)   // #211f1d
    static let secondaryBtnBorder = Color(red: 0.886, green: 0.859, blue: 0.824)  // #e2dbd2
    static let secondaryBtnBg = Color.white                                         // #fff
    static let secondaryBtnText = Color(red: 0.365, green: 0.333, blue: 0.306)    // #5d554e
    static let secondaryBtnHoverBg = Color(red: 0.965, green: 0.949, blue: 0.929) // #f6f2ed
    static let completeBtnBg = Color(red: 0.408, green: 0.769, blue: 0.420)       // #68c46b
    static let completeBtnHoverBg = Color(red: 0.337, green: 0.682, blue: 0.361)  // #56ae5c
    static let destructiveBtnBorder = Color(red: 0.937, green: 0.788, blue: 0.773) // #efc9c5
    static let destructiveBtnBg = Color(red: 1.0, green: 0.941, blue: 0.929)      // #fff0ed
    static let destructiveBtnText = Color(red: 0.749, green: 0.322, blue: 0.294)  // #bf524b

    // Completion toggle
    static let completionTitle = Color(red: 0.176, green: 0.176, blue: 0.176)     // #2d2d2d
    static let completionHint = Color(red: 0.604, green: 0.565, blue: 0.533)     // #9a9088
    static let toggleOffBg = Color(red: 0.784, green: 0.757, blue: 0.725)        // #c8c1b9
    static let toggleOnBg = Color(red: 0.298, green: 0.847, blue: 0.392)         // #4cd964
    static let toggleKnob = Color.white

    // Task row start button
    static let startBtnBorder = Color(red: 0.894, green: 0.867, blue: 0.831)     // #e4ddd4
    static let startBtnBg = Color(red: 1.0, green: 0.996, blue: 0.980)           // #fffefa
    static let startBtnText = Color(red: 0.376, green: 0.345, blue: 0.310)      // #60584f
    static let startBtnHoverBg = Color(red: 0.945, green: 0.929, blue: 0.910)   // #f1ede8
}

private enum PomodoroMetrics {
    // Focus card
    static let focusCardCornerRadius: CGFloat = 16
    static let focusCardPadding: CGFloat = 12
    static let focusCardRingSize: CGFloat = 68
    static let focusCardRingInset: CGFloat = 5
    static let focusCardRingTextSize: CGFloat = 15
    static let focusCardColumnGap: CGFloat = 12
    static let focusCardRowGap: CGFloat = 8
    static let focusCardTitleSize: CGFloat = 13
    static let focusCardMetaSize: CGFloat = 10
    static let focusCardActionHeight: CGFloat = 28
    static let focusCardActionSpacing: CGFloat = 5

    // Dialog shell
    static let dialogCornerRadius: CGFloat = 16
    static let dialogWidth: CGFloat = 300
    static let dialogPaddingTop: CGFloat = 22
    static let dialogPaddingBottom: CGFloat = 22
    static let dialogPaddingHorizontal: CGFloat = 20
    static let dialogActionsTopSpacing: CGFloat = 18

    // Dialog text
    static let kickerSize: CGFloat = 17
    static let titleSize: CGFloat = 17
    static let bodySize: CGFloat = 12
    static let hintSize: CGFloat = 11

    // Duration picker
    static let fieldLabelBottomSpacing: CGFloat = 9
    static let fieldLabelSize: CGFloat = 12
    static let optionHeight: CGFloat = 38
    static let optionSpacing: CGFloat = 7
    static let optionTextSize: CGFloat = 11
    static let customHeight: CGFloat = 38
    static let customTopSpacing: CGFloat = 8
    static let customInputSize: CGFloat = 12
    static let customUnitSize: CGFloat = 11

    // Buttons
    static let buttonHeight: CGFloat = 38
    static let buttonSpacing: CGFloat = 8
    static let buttonTextSize: CGFloat = 12

    // Completion toggle
    static let completionLineTopSpacing: CGFloat = 18
    static let completionTitleSize: CGFloat = 13
    static let completionHintSize: CGFloat = 10
    static let toggleWidth: CGFloat = 40
    static let toggleHeight: CGFloat = 24
    static let toggleKnobSize: CGFloat = 18
    static let toggleKnobInset: CGFloat = 3

    // Task row start button
    static let startBtnHeight: CGFloat = 24
    static let startBtnHorizontalPadding: CGFloat = 8
    static let startBtnTextSize: CGFloat = 10
    static let startBtnCornerRadius: CGFloat = 8
}

/// Adds negative tracking to short labels so they match the existing widget typography.
private struct PomodoroTrackingModifier: ViewModifier {
    let value: CGFloat
    func body(content: Content) -> some View {
        content.tracking(value)
    }
}

// MARK: - Focus Card

/// Conditional card shown above the task list while a Pomodoro session is active or paused.
/// Renders nothing when `viewModel.pomodoroSession` is nil so no empty space is reserved.
struct PomodoroFocusCard: View {
    @ObservedObject var viewModel: TodoListViewModel
    @EnvironmentObject private var languageStore: LanguageStore

    var body: some View {
        if let session = viewModel.pomodoroSession {
            // CSS: grid-template-columns: 68px minmax(0,1fr); grid-template-areas: "ring copy" "ring controls"
            HStack(alignment: .center, spacing: PomodoroMetrics.focusCardColumnGap) {
                countdownRing(session: session)

                VStack(alignment: .leading, spacing: PomodoroMetrics.focusCardRowGap) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.taskTitle)
                            .font(.system(size: PomodoroMetrics.focusCardTitleSize, weight: .bold))
                            .foregroundStyle(PomodoroPalette.focusTitle)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Text(metaText(for: session))
                            .font(.system(size: PomodoroMetrics.focusCardMetaSize, weight: .semibold))
                            .foregroundStyle(PomodoroPalette.focusMeta)
                    }

                    // controls: grid-template-columns: repeat(3, minmax(0,1fr)); gap: 5px
                    HStack(spacing: PomodoroMetrics.focusCardActionSpacing) {
                        focusActionButton(
                            key: .pomodoroAbandon,
                            textColor: PomodoroPalette.focusActionText,
                            border: PomodoroPalette.focusActionBorder,
                            bg: PomodoroPalette.focusActionBg,
                            action: { viewModel.requestPomodoroAbandon() }
                        )

                        focusActionButton(
                            key: session.phase == .paused ? .pomodoroResumeFocus : .pomodoroPause,
                            textColor: PomodoroPalette.focusActionText,
                            border: PomodoroPalette.focusActionBorder,
                            bg: PomodoroPalette.focusActionBg,
                            action: {
                                if session.phase == .paused {
                                    viewModel.resumePomodoro()
                                } else {
                                    viewModel.pausePomodoro()
                                }
                            }
                        )

                        focusActionButton(
                            key: .pomodoroComplete,
                            textColor: PomodoroPalette.focusCompleteText,
                            border: PomodoroPalette.focusCompleteBorder,
                            bg: PomodoroPalette.focusCompleteBg,
                            action: { viewModel.requestPomodoroManualCompletion() }
                        )
                    }
                }
            }
            .padding(PomodoroMetrics.focusCardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: PomodoroMetrics.focusCardCornerRadius, style: .continuous)
                    .fill(PomodoroPalette.focusCardBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PomodoroMetrics.focusCardCornerRadius, style: .continuous)
                    .stroke(PomodoroPalette.focusCardBorder, lineWidth: 1)
            )
            .padding(.bottom, 12)
        }
    }

    @ViewBuilder
    private func countdownRing(session: PomodoroSession) -> some View {
        let totalSeconds = max(1, session.durationMinutes * 60)
        let remaining = max(0, min(session.remainingSeconds, totalSeconds))
        let progress = Double(remaining) / Double(totalSeconds)

        ZStack {
            // conic-gradient(#a17c59 0deg 18deg, #eee4d8 18deg 360deg) approximated with trim
            Circle()
                .stroke(PomodoroPalette.ringTrack, lineWidth: 6)

            Circle()
                .trim(from: 0, to: max(0.02, progress))
                .stroke(PomodoroPalette.ringFill, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))

            // inner background disc (::before inset: 5px)
            Circle()
                .fill(PomodoroPalette.ringInnerBg)
                .frame(width: PomodoroMetrics.focusCardRingSize - PomodoroMetrics.focusCardRingInset * 2,
                       height: PomodoroMetrics.focusCardRingSize - PomodoroMetrics.focusCardRingInset * 2)

            Text(formattedTime(seconds: remaining))
                .font(.system(size: PomodoroMetrics.focusCardRingTextSize, weight: .bold, design: .monospaced))
                .foregroundStyle(PomodoroPalette.ringTextColor)
                .tracking(-0.8)
        }
        .frame(width: PomodoroMetrics.focusCardRingSize, height: PomodoroMetrics.focusCardRingSize)
    }

    private func metaText(for session: PomodoroSession) -> String {
        switch session.phase {
        case .running, .finished:
            return languageStore.text(.pomodoroFocusCardMeta, session.durationMinutes)
        case .paused:
            return languageStore.text(.pomodoroFocusCardPausedMeta)
        }
    }

    private func formattedTime(seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    @ViewBuilder
    private func focusActionButton(
        key: AppText.Key,
        textColor: Color,
        border: Color,
        bg: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(languageStore.text(key))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(textColor)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(height: PomodoroMetrics.focusCardActionHeight)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(bg)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shared Dialog Shell

/// Shared dialog container matching `.pomo-dialog` in the HTML prototype:
/// white-cream background, 16pt corner radius, subtle border, warm shadow.
struct PomodoroDialogShell<Content: View>: View {
    let content: Content
    let width: CGFloat

    init(width: CGFloat = PomodoroMetrics.dialogWidth, @ViewBuilder content: () -> Content) {
        self.width = width
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            content
        }
        .padding(EdgeInsets(
            top: PomodoroMetrics.dialogPaddingTop,
            leading: PomodoroMetrics.dialogPaddingHorizontal,
            bottom: PomodoroMetrics.dialogPaddingBottom,
            trailing: PomodoroMetrics.dialogPaddingHorizontal
        ))
        .frame(width: width)
        .background(
            RoundedRectangle(cornerRadius: PomodoroMetrics.dialogCornerRadius, style: .continuous)
                .fill(PomodoroPalette.dialogBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PomodoroMetrics.dialogCornerRadius, style: .continuous)
                .stroke(PomodoroPalette.dialogBorder, lineWidth: 1)
        )
        .shadow(color: PomodoroPalette.dialogShadow, radius: 22, y: 10)
    }
}

/// Transparent scrim. The user explicitly asked for no grey overlay behind
/// Pomodoro dialogs, so we keep the area tappable but visually clear.
struct PomodoroScrim: View {
    let onDismiss: () -> Void

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .contentShape(Rectangle())
            .onTapGesture { onDismiss() }
    }
}

// MARK: - Dialog Text Primitives

struct PomodoroKicker: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: PomodoroMetrics.kickerSize, weight: .bold))
            .foregroundStyle(PomodoroPalette.kickerText)
            .tracking(-0.17)
    }
}

struct PomodoroDialogTitle: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: PomodoroMetrics.titleSize, weight: .bold))
            .foregroundStyle(PomodoroPalette.kickerText)
            .tracking(-0.34)
            .lineSpacing(2)
            .multilineTextAlignment(.center)
    }
}

struct PomodoroDialogBody: View {
    let text: String
    var color: Color = PomodoroPalette.bodyText
    var body: some View {
        Text(text)
            .font(.system(size: PomodoroMetrics.bodySize, weight: .medium))
            .foregroundStyle(color)
            .multilineTextAlignment(.center)
            .lineSpacing(2.4)
    }
}

struct PomodoroDialogHint: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: PomodoroMetrics.hintSize, weight: .semibold))
            .foregroundStyle(PomodoroPalette.hintText)
            .multilineTextAlignment(.center)
            .lineSpacing(1.6)
    }
}

// MARK: - Dialog Buttons

/// `.pomo-button.primary`: #34312e bg, white text, 9pt radius, 38pt height
struct PomodoroPrimaryButton: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: PomodoroMetrics.buttonTextSize, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: PomodoroMetrics.buttonHeight)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(PomodoroPalette.primaryBtnBg)
                )
        }
        .buttonStyle(.plain)
    }
}

/// `.pomo-button.secondary`: white bg, #e2dbd2 border, #5d554e text
struct PomodoroSecondaryButton: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: PomodoroMetrics.buttonTextSize, weight: .bold))
                .foregroundStyle(PomodoroPalette.secondaryBtnText)
                .frame(maxWidth: .infinity)
                .frame(height: PomodoroMetrics.buttonHeight)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(PomodoroPalette.secondaryBtnBg)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(PomodoroPalette.secondaryBtnBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

/// `.pomo-button.complete`: #68c46b bg, white text
struct PomodoroCompleteButton: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: PomodoroMetrics.buttonTextSize, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: PomodoroMetrics.buttonHeight)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(PomodoroPalette.completeBtnBg)
                )
        }
        .buttonStyle(.plain)
    }
}

/// `.pomo-button.destructive`: #fff0ed bg, #efc9c5 border, #bf524b text
struct PomodoroDestructiveButton: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: PomodoroMetrics.buttonTextSize, weight: .bold))
                .foregroundStyle(PomodoroPalette.destructiveBtnText)
                .frame(maxWidth: .infinity)
                .frame(height: PomodoroMetrics.buttonHeight)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(PomodoroPalette.destructiveBtnBg)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(PomodoroPalette.destructiveBtnBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

/// `.pomo-dialog-actions`: centered HStack with 8pt gap
struct PomodoroDialogActions: View {
    let spacing: CGFloat = PomodoroMetrics.buttonSpacing
    @ViewBuilder let content: () -> AnyView

    var body: some View {
        HStack(spacing: spacing) {
            content()
        }
        .padding(.top, PomodoroMetrics.dialogActionsTopSpacing)
    }
}

// MARK: - Duration Picker

/// `.pomo-duration-setting`: field label + 3-option grid + optional custom input
struct PomodoroDurationPicker: View {
    @ObservedObject var viewModel: TodoListViewModel
    @EnvironmentObject private var languageStore: LanguageStore
    @FocusState private var isCustomMinutesFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(languageStore.text(.pomodoroDurationFieldLabel))
                .font(.system(size: PomodoroMetrics.fieldLabelSize, weight: .bold))
                .foregroundStyle(PomodoroPalette.fieldLabel)
                .padding(.bottom, PomodoroMetrics.fieldLabelBottomSpacing)

            HStack(spacing: PomodoroMetrics.optionSpacing) {
                optionButton(minutes: 25, label: .pomodoroDurationPreset25)
                optionButton(minutes: 45, label: .pomodoroDurationPreset45)
                optionButton(minutes: -1, label: .pomodoroDurationCustom)
            }

            if viewModel.pomodoroSelectedMinutes == -1 {
                customInput
                    .padding(.top, PomodoroMetrics.customTopSpacing)
                    .onAppear {
                        DispatchQueue.main.async {
                            isCustomMinutesFocused = true
                        }
                    }
            }

            // error slot
            if let error = viewModel.pomodoroDurationError {
                Text(languageStore.text(error))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(PomodoroPalette.durationErrorText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 5)
            }
        }
    }

    @ViewBuilder
    private func optionButton(minutes: Int, label: AppText.Key) -> some View {
        let isSelected = viewModel.pomodoroSelectedMinutes == minutes
        Button {
            viewModel.selectPomodoroPreset(minutes)
        } label: {
            Text(languageStore.text(label))
                .font(.system(size: PomodoroMetrics.optionTextSize, weight: .bold))
                .foregroundStyle(isSelected ? PomodoroPalette.optionSelectedText : PomodoroPalette.optionText)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(height: PomodoroMetrics.optionHeight)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(isSelected ? PomodoroPalette.optionSelectedBg : PomodoroPalette.optionBg)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(isSelected ? PomodoroPalette.optionSelectedBorder : PomodoroPalette.optionBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var customInput: some View {
        HStack(spacing: 0) {
            TextField(
                languageStore.text(.pomodoroDurationCustomPlaceholder),
                text: $viewModel.pomodoroCustomMinutesText
            )
            .font(.system(size: PomodoroMetrics.customInputSize, weight: .bold))
            .foregroundStyle(PomodoroPalette.customInputText)
            .textFieldStyle(.plain)
            .focused($isCustomMinutesFocused)
            .onSubmit {
                if viewModel.validatePomodoroCustomMinutes() != nil {
                    viewModel.beginPomodoro()
                }
            }

            Spacer(minLength: 10)

            Text(languageStore.text(.pomodoroDurationUnit))
                .font(.system(size: PomodoroMetrics.customUnitSize, weight: .bold))
                .foregroundStyle(PomodoroPalette.customUnitText)
                .padding(.leading, 10)
                .overlay(
                    Rectangle()
                        .fill(PomodoroPalette.customDivider)
                        .frame(width: 1)
                        .padding(.trailing, 9),
                    alignment: .leading
                )
        }
        .padding(.horizontal, 12)
        .frame(height: PomodoroMetrics.customHeight)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(PomodoroPalette.customBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(
                    isCustomMinutesFocused ? PomodoroPalette.customFocusedBorder : PomodoroPalette.customBorder,
                    lineWidth: 1
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(PomodoroPalette.customFocusRing, lineWidth: 2)
                .padding(-2)
                .opacity(isCustomMinutesFocused ? 1 : 0)
        )
        .animation(.easeInOut(duration: 0.15), value: isCustomMinutesFocused)
    }
}

// MARK: - Completion Toggle

/// `.pomo-completion-line`: horizontal toggle with title + hint on the left,
/// iOS-style switch on the right. Defaults off.
struct PomodoroCompletionToggle: View {
    @ObservedObject var viewModel: TodoListViewModel
    @EnvironmentObject private var languageStore: LanguageStore

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(languageStore.text(.pomodoroCompleteTaskToggle))
                    .font(.system(size: PomodoroMetrics.completionTitleSize, weight: .bold))
                    .foregroundStyle(PomodoroPalette.completionTitle)
                    .tracking(-0.13)

                Text(viewModel.pomodoroCompleteTaskToggle
                     ? languageStore.text(.pomodoroCompleteTaskToggleOnHint)
                     : languageStore.text(.pomodoroCompleteTaskToggleOffHint))
                    .font(.system(size: PomodoroMetrics.completionHintSize, weight: .medium))
                    .foregroundStyle(PomodoroPalette.completionHint)
                    .lineSpacing(1.45)
            }

            Spacer(minLength: 0)

            PomodoroSwitch(isOn: $viewModel.pomodoroCompleteTaskToggle)
        }
        .padding(.horizontal, 2)
        .padding(.top, PomodoroMetrics.completionLineTopSpacing)
    }
}

/// iOS-style switch matching `.pomo-completion-line input` (40x24 capsule).
struct PomodoroSwitch: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            ZStack {
                Capsule(style: .continuous)
                    .fill(isOn ? PomodoroPalette.toggleOnBg : PomodoroPalette.toggleOffBg)

                Circle()
                    .fill(PomodoroPalette.toggleKnob)
                    .shadow(color: Color.black.opacity(0.17), radius: 1, y: 1)
                    .frame(width: PomodoroMetrics.toggleKnobSize, height: PomodoroMetrics.toggleKnobSize)
                    .offset(x: isOn
                            ? (PomodoroMetrics.toggleWidth - PomodoroMetrics.toggleKnobSize - PomodoroMetrics.toggleKnobInset) / 2 - PomodoroMetrics.toggleKnobInset / 2
                            : -(PomodoroMetrics.toggleWidth - PomodoroMetrics.toggleKnobSize - PomodoroMetrics.toggleKnobInset) / 2 + PomodoroMetrics.toggleKnobInset / 2)
            }
            .frame(width: PomodoroMetrics.toggleWidth, height: PomodoroMetrics.toggleHeight)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.16), value: isOn)
    }
}

// MARK: - Start Dialog

/// Start-focus overlay matching `.pomo-dialog.is-start`.
/// Layout: kicker -> h2 (task title) -> p (copy) -> duration picker -> actions -> hint.
struct PomodoroStartCard: View {
    @ObservedObject var viewModel: TodoListViewModel
    @EnvironmentObject private var languageStore: LanguageStore

    var body: some View {
        if let task = viewModel.pomodoroStartTask {
            ZStack {
                PomodoroScrim { viewModel.cancelPomodoroStart() }

                PomodoroDialogShell {
                    VStack(spacing: 6) {
                        PomodoroKicker(text: languageStore.text(.pomodoroStartDialogTitle))
                            .padding(.bottom, 2)

                        PomodoroDialogTitle(text: task.title)
                            .padding(.bottom, 2)

                        PomodoroDialogBody(
                            text: languageStore.text(.pomodoroStartDialogCopy),
                            color: PomodoroPalette.startBodyText
                        )
                        .padding(.bottom, 20)
                    }

                    PomodoroDurationPicker(viewModel: viewModel)

                    let effectiveMinutes: Int? = {
                        if viewModel.pomodoroSelectedMinutes == -1 {
                            return viewModel.validatePomodoroCustomMinutes()
                        }
                        return viewModel.pomodoroSelectedMinutes
                    }()
                    let beginButtonText = effectiveMinutes
                        .map { languageStore.text(.pomodoroStartDialogBegin, $0) }
                        ?? languageStore.text(.pomodoroStartDialogBeginGeneric)

                    PomodoroDialogActions {
                        AnyView(
                            HStack(spacing: PomodoroMetrics.buttonSpacing) {
                                PomodoroSecondaryButton(
                                    text: languageStore.text(.pomodoroStartDialogCancel)
                                ) {
                                    viewModel.cancelPomodoroStart()
                                }

                                PomodoroPrimaryButton(
                                    text: beginButtonText
                                ) {
                                    viewModel.beginPomodoro()
                                }
                                .disabled(effectiveMinutes == nil)
                                .keyboardShortcut(.defaultAction)
                            }
                        )
                    }

                }
            }
        }
    }
}

// MARK: - Prompt Dialog

/// Routes the current `PomodoroPrompt` to the matching dialog body.
struct PomodoroPromptCard: View {
    @ObservedObject var viewModel: TodoListViewModel
    @EnvironmentObject private var languageStore: LanguageStore

    var body: some View {
        if let prompt = viewModel.pomodoroPrompt {
            ZStack {
                PomodoroScrim { viewModel.resumePomodoro() }

                dialog(for: prompt)
            }
        }
    }

    @ViewBuilder
    private func dialog(for prompt: PomodoroPrompt) -> some View {
        switch prompt {
        case .pause:
            pauseDialog
        case .abandon:
            abandonDialog
        case .manualCompletion(let minutesToAdd):
            manualEndDialog(minutesToAdd: minutesToAdd)
        case .naturalEnd(let minutesToAdd):
            naturalEndDialog(minutesToAdd: minutesToAdd)
        case .durationWriteFailed:
            durationWriteFailedDialog
        case .success(let completedTask, let minutesToAdd):
            successDialog(completedTask: completedTask, minutesToAdd: minutesToAdd)
        }
    }

    // MARK: Pause

    @ViewBuilder
    private var pauseDialog: some View {
        PomodoroDialogShell {
            PomodoroDialogTitle(text: languageStore.text(.pomodoroPauseDialogTitle))
                .padding(.bottom, 8)

            PomodoroDialogBody(text: languageStore.text(.pomodoroPauseDialogCopy))

            PomodoroDialogActions {
                AnyView(
                    HStack(spacing: PomodoroMetrics.buttonSpacing) {
                        PomodoroSecondaryButton(
                            text: languageStore.text(.pomodoroPauseAbandonRound)
                        ) {
                            viewModel.requestPomodoroAbandon()
                        }

                        PomodoroPrimaryButton(
                            text: languageStore.text(.pomodoroResumeFocus)
                        ) {
                            viewModel.resumePomodoro()
                        }
                    }
                )
            }
        }
    }

    // MARK: Abandon

    @ViewBuilder
    private var abandonDialog: some View {
        PomodoroDialogShell {
            PomodoroDialogTitle(text: languageStore.text(.pomodoroAbandonDialogTitle))
                .padding(.bottom, 8)

            PomodoroDialogBody(text: languageStore.text(.pomodoroAbandonDialogCopy))

            PomodoroDialogActions {
                AnyView(
                    HStack(spacing: PomodoroMetrics.buttonSpacing) {
                        PomodoroSecondaryButton(
                            text: languageStore.text(.pomodoroResumeFocus)
                        ) {
                            viewModel.resumePomodoro()
                        }

                        PomodoroDestructiveButton(
                            text: languageStore.text(.pomodoroConfirmAbandon)
                        ) {
                            viewModel.confirmPomodoroAbandon()
                        }
                    }
                )
            }
        }
    }

    // MARK: Manual end (`.pomo-dialog` with kicker + completion choice)

    @ViewBuilder
    private func manualEndDialog(minutesToAdd: Int) -> some View {
        PomodoroDialogShell {
            PomodoroKicker(text: languageStore.text(.pomodoroEndFocusKicker))
                .padding(.bottom, 6)

            PomodoroDialogBody(
                text: languageStore.text(.pomodoroEndFocusDialogCopy, minutesToAdd),
                color: PomodoroPalette.bodyText
            )

            PomodoroCompletionToggle(viewModel: viewModel)

            PomodoroDialogActions {
                AnyView(
                    HStack(spacing: PomodoroMetrics.buttonSpacing) {
                        PomodoroSecondaryButton(
                            text: languageStore.text(.pomodoroResumeFocus)
                        ) {
                            viewModel.resumePomodoro()
                        }

                        if viewModel.pomodoroCompleteTaskToggle {
                            PomodoroCompleteButton(
                                text: languageStore.text(.pomodoroRecordAndComplete)
                            ) {
                                Task { await viewModel.confirmPomodoroManualCompletion() }
                            }
                        } else {
                            PomodoroPrimaryButton(
                                text: languageStore.text(.pomodoroRecordDuration)
                            ) {
                                Task { await viewModel.confirmPomodoroManualCompletion() }
                            }
                        }
                    }
                )
            }
        }
    }

    // MARK: Natural end (`.pomo-dialog.is-success`-ish: single action)

    @ViewBuilder
    private func naturalEndDialog(minutesToAdd: Int) -> some View {
        PomodoroDialogShell {
            PomodoroKicker(text: languageStore.text(.pomodoroRoundComplete))
                .padding(.bottom, 6)

            PomodoroDialogBody(
                text: languageStore.text(.pomodoroRoundCompleteCopy, minutesToAdd),
                color: PomodoroPalette.bodyText
            )

            PomodoroDialogHint(text: languageStore.text(.pomodoroRoundCompleteHint))
                .padding(.top, 4)

            PomodoroCompletionToggle(viewModel: viewModel)

            PomodoroDialogActions {
                AnyView(
                    Group {
                        if viewModel.pomodoroCompleteTaskToggle {
                            PomodoroCompleteButton(
                                text: languageStore.text(.pomodoroCompleteTask)
                            ) {
                                Task { await viewModel.confirmPomodoroNaturalEnd() }
                            }
                        } else {
                            PomodoroPrimaryButton(
                                text: languageStore.text(.pomodoroKeepIncomplete)
                            ) {
                                Task { await viewModel.confirmPomodoroNaturalEnd() }
                            }
                        }
                    }
                )
            }
        }
    }

    // MARK: Duration write failure

    @ViewBuilder
    private var durationWriteFailedDialog: some View {
        PomodoroDialogShell {
            PomodoroDialogTitle(text: languageStore.text(.pomodoroDurationWriteFailed))
                .padding(.bottom, 8)

            if let error = viewModel.pomodoroDurationWriteError {
                PomodoroDialogBody(text: languageStore.text(error))
            }

            PomodoroDialogActions {
                AnyView(
                    HStack(spacing: PomodoroMetrics.buttonSpacing) {
                        PomodoroSecondaryButton(
                            text: languageStore.text(.pomodoroLater)
                        ) {
                            viewModel.dismissPomodoroLater()
                        }

                        PomodoroPrimaryButton(
                            text: languageStore.text(.pomodoroRetryDurationWrite)
                        ) {
                            Task { await viewModel.retryPomodoroDurationWrite() }
                        }
                    }
                )
            }
        }
    }

    // MARK: Success (`.pomo-dialog.is-success`: single centered button)

    @ViewBuilder
    private func successDialog(completedTask: Bool, minutesToAdd: Int) -> some View {
        let copy: AppText.Key = completedTask ? .pomodoroSuccessCompleted : .pomodoroSuccessIncomplete
        PomodoroDialogShell {
            PomodoroDialogBody(
                text: languageStore.text(copy, minutesToAdd),
                color: PomodoroPalette.successBodyText
            )
            .padding(.top, 2)

            PomodoroDialogActions {
                AnyView(
                    PomodoroPrimaryButton(
                        text: languageStore.text(.pomodoroDone)
                    ) {
                        viewModel.dismissPomodoroSuccess()
                    }
                    .frame(maxWidth: 200)
                )
            }
        }
    }
}

// MARK: - Task Row Timer Start Action

/// `.pomo-start-btn`: compact 24pt-tall capsule appended to incomplete task rows.
struct PomodoroTaskRowStartAction: View {
    @ObservedObject var viewModel: TodoListViewModel
    let task: TaskItem
    @EnvironmentObject private var languageStore: LanguageStore

    private var isDisabled: Bool {
        viewModel.pomodoroSession != nil
            || viewModel.pomodoroStartTask != nil
            || viewModel.pomodoroPrompt != nil
    }

    var body: some View {
        Button {
            viewModel.presentPomodoroStart(for: task)
        } label: {
            Text(languageStore.text(.pomodoroTaskStartAction))
                .font(.system(size: PomodoroMetrics.startBtnTextSize, weight: .heavy))
                .foregroundStyle(isDisabled ? PomodoroPalette.completionHint : PomodoroPalette.startBtnText)
                .padding(.horizontal, PomodoroMetrics.startBtnHorizontalPadding)
                .frame(height: PomodoroMetrics.startBtnHeight)
                .background(
                    RoundedRectangle(cornerRadius: PomodoroMetrics.startBtnCornerRadius, style: .continuous)
                        .fill(PomodoroPalette.startBtnBg)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PomodoroMetrics.startBtnCornerRadius, style: .continuous)
                        .stroke(PomodoroPalette.startBtnBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.4 : 1)
    }
}
