import SwiftUI

struct NewTaskFormCard: View {
    @ObservedObject var viewModel: NewTaskViewModel
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
            Text("➕ 新建任务")
                .font(.system(size: 14, weight: .medium))

            TextField("标题(必填)", text: $viewModel.title)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(viewModel.formState == .validationFailed ? Color.red : Color.secondary.opacity(0.3), lineWidth: viewModel.formState == .validationFailed ? 1.5 : 1)
                )
                .modifier(ShakeEffect(animatableData: viewModel.shakeAttempts))
                .focused($isTitleFocused)
                .onAppear {
                    isTitleFocused = true
                }

            if viewModel.formState == .validationFailed {
                Text("标题不能为空")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                DatePicker("", selection: $viewModel.taskDate, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
            }

            HStack {
                Button("Esc 取消") {
                    viewModel.dismissForm()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

                Spacer()

                Button("Enter 创建") {
                    viewModel.submit()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.accentColor)
            }
        }
        .padding(16)
        .frame(width: 280, height: 190)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }
}
