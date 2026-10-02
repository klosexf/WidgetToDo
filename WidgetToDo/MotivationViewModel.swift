import Combine
import Foundation

/// 激励话术浮窗顶部条的状态：显示开关、单行文案、编辑弹框是否展开。
///
/// 持久化走独立的 `MotivationQuoteStore`，不经过 `SettingsStore` / `AppSettings`，
/// 因此新增这一项不会影响既有配置的编解码。
@MainActor
final class MotivationViewModel: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var quote = ""
    /// 编辑弹框展开状态。
    @Published var isEditorPresented = false

    private let store: MotivationQuoteStore

    init(store: MotivationQuoteStore = MotivationQuoteStore()) {
        self.store = store
    }

    /// 启动时读取。读盘失败保持默认（关闭 + 空文案），不打断启动流程。
    func load() async {
        let snapshot = await store.snapshot()
        isEnabled = snapshot.enabled
        quote = snapshot.text
    }

    func setEnabled(_ enabled: Bool) {
        guard isEnabled != enabled else { return }
        isEnabled = enabled
        if !enabled { isEditorPresented = false }
        let store = self.store
        Task { await store.setEnabled(enabled) }
    }

    func beginEditing() {
        isEditorPresented = true
    }

    func cancelEditing() {
        isEditorPresented = false
    }

    /// 保存文案。空串等同于未设置：顶部条会退回占位提示。
    func save(_ text: String) {
        quote = text
        isEditorPresented = false
        let store = self.store
        Task { await store.setText(text) }
    }
}
