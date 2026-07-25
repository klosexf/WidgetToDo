import AppKit
import Darwin

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: AppCoordinator?

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    func application(_ application: NSApplication, shouldRestoreApplicationState coder: NSCoder) -> Bool {
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        NSApp.disableRelaunchOnLogin()
        terminateOtherRunningInstances()

        do {
            let coordinator = try AppCoordinator()
            self.coordinator = coordinator
            coordinator.start()
            scheduleDeferredInstanceCleanup()
        } catch {
            let alert = NSAlert()
            alert.messageText = LanguageStore.shared.text(.startupFailed, error.localizedDescription)
            alert.informativeText = error.localizedDescription
            alert.runModal()
            NSApp.terminate(nil)
        }
    }

    private func scheduleDeferredInstanceCleanup() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.terminateOtherRunningInstances()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.terminateOtherRunningInstances()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.terminateOtherRunningInstances()
        }
    }

    private func terminateOtherRunningInstances() {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return }
        let currentPID = ProcessInfo.processInfo.processIdentifier

        for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
        where app.processIdentifier != currentPID
        {
            if !app.terminate() {
                _ = app.forceTerminate()
            }
            kill(app.processIdentifier, SIGKILL)
        }
    }
}
