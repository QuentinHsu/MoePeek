import AppKit
import Defaults
import KeyboardShortcuts

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

        setupShortcuts()
        setupSelectionMonitor()

        // Show onboarding on first launch; start polling if permissions not fully granted
        if !Defaults[.hasCompletedOnboarding] {
            onboardingController.showWindow()
        }
        if !permissionManager.allPermissionsGranted {
            permissionManager.startPolling()
        }
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
