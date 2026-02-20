import Defaults
import KeyboardShortcuts
import SwiftUI

/// Content for the menu bar dropdown.
struct MenuItemView: View {
    let appDelegate: AppDelegate
    @Environment(\.openSettings) private var openSettings

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    var body: some View {
        Text("MoePeek \(appVersion)")
            .font(.headline)

        Divider()

        Button {
            guard let coordinator = appDelegate.coordinator,
                  let panelController = appDelegate.panelController else { return }
            coordinator.prepareInputMode()
            panelController.showAtScreenCenter()
        } label: {
            Label("手动翻译", systemImage: "keyboard")
        }
        .keyboardShortcut("a", modifiers: .option)

        Button {
            guard let coordinator = appDelegate.coordinator,
                  let panelController = appDelegate.panelController else { return }
            Task {
                await coordinator.ocrAndTranslate()
                if case .idle = coordinator.phase { return }
                panelController.showAtCursor()
            }
        } label: {
            Label("截图 OCR", systemImage: "text.viewfinder")
        }
        .keyboardShortcut("s", modifiers: .option)

        Button {
            guard let coordinator = appDelegate.coordinator,
                  let panelController = appDelegate.panelController else { return }
            Task {
                await coordinator.translateSelection()
                panelController.showAtCursor()
            }
        } label: {
            Label("选中翻译", systemImage: "text.cursor")
        }
        .keyboardShortcut("d", modifiers: .option)

        Button {
            guard let coordinator = appDelegate.coordinator,
                  let panelController = appDelegate.panelController else { return }
            coordinator.translateClipboard()
            panelController.showAtCursor()
        } label: {
            Label("剪贴翻译", systemImage: "doc.on.clipboard")
        }
        .keyboardShortcut("v", modifiers: .option)

        Divider()

        Button {
            appDelegate.onboardingController.showWindow()
        } label: {
            Label("引导设置...", systemImage: "questionmark.circle")
        }

        Button {
            openSettings()
        } label: {
            Label("设置...", systemImage: "gearshape")
        }
        .keyboardShortcut(",")

        Divider()

        Button("退出 MoePeek") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
