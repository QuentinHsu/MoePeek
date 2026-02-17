import AppKit
import Defaults
import KeyboardShortcuts

extension Notification.Name {
    static let openSettings = Notification.Name("MoePeek.openSettings")
}

/// Handles app lifecycle, permission checks, and global shortcut registration.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var coordinator: TranslationCoordinator!
    var panelController: PopupPanelController!
    var permissionManager: PermissionManager!
    var onboardingController: OnboardingWindowController!
    var selectionMonitor: SelectionMonitor!
    var triggerIconController: TriggerIconController!

    func applicationDidFinishLaunching(_: Notification) {
        permissionManager = PermissionManager()
        coordinator = TranslationCoordinator(permissionManager: permissionManager)
        panelController = PopupPanelController(coordinator: coordinator)
        onboardingController = OnboardingWindowController(permissionManager: permissionManager)
        selectionMonitor = SelectionMonitor()
        triggerIconController = TriggerIconController()

        // Apply dock visibility — only switch to .regular when needed;
        // LSUIElement=YES already provides .accessory by default.
        if Defaults[.showInDock] {
            NSApp.setActivationPolicy(.regular)
        }

        setupShortcuts()
        setupSelectionMonitor()

        // Show onboarding on first launch; otherwise open Settings directly.
        // Defer openSettings so SwiftUI MenuBarExtra scene has registered
        // its @Environment(\.openSettings) listener first.
        if !Defaults[.hasCompletedOnboarding] {
            onboardingController.onComplete = { [weak self] in
                self?.openSettings()
            }
            onboardingController.showWindow()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.openSettings()
            }
        }
        if !permissionManager.allPermissionsGranted {
            permissionManager.startPolling()
        }
    }

    func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .openSettings, object: nil)
    }

    private func setupShortcuts() {
        KeyboardShortcuts.onKeyUp(for: .translateSelection) { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await self.coordinator.translateSelection()
                if case .idle = self.coordinator.state { return }
                self.panelController.showAtCursor()
            }
        }

        KeyboardShortcuts.onKeyUp(for: .ocrScreenshot) { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await self.coordinator.ocrAndTranslate()
                if case .idle = self.coordinator.state { return }
                self.panelController.showAtCursor()
            }
        }
    }

    private func setupSelectionMonitor() {
        selectionMonitor.onTextSelected = { [weak self] text, point in
            guard let self, !self.panelController.isVisible else { return }
            self.triggerIconController.show(text: text, near: point)
        }

        selectionMonitor.onMouseDown = { [weak self] _ in
            guard let self, self.triggerIconController.isVisible else { return }
            self.triggerIconController.dismiss()
        }

        triggerIconController.onTranslateRequested = { [weak self] text in
            guard let self else { return }
            Task { @MainActor in
                await self.coordinator.translate(text)
                if case .idle = self.coordinator.state { return }
                self.panelController.showAtCursor()
            }
        }

        triggerIconController.onDismissed = { [weak self] in
            self?.selectionMonitor.suppressBriefly()
        }

        panelController.onDismiss = { [weak self] in
            self?.selectionMonitor.suppressBriefly()
            if self?.triggerIconController.isVisible == true {
                self?.triggerIconController.dismiss()
            }
        }

        selectionMonitor.start()
    }
}
