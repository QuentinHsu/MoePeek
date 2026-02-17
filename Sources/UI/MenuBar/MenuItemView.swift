import KeyboardShortcuts
import SwiftUI

/// Content for the menu bar dropdown.
struct MenuItemView: View {
    let appDelegate: AppDelegate

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        Text("MoePeek v\(appVersion)")

        Divider()

        Button("显示引导页") {
            appDelegate.onboardingController?.showWindow()
        }

        Divider()

        Button("翻译选中文字") {
            guard let coordinator = appDelegate.coordinator,
                  let panelController = appDelegate.panelController else { return }
            Task {
                await coordinator.translateSelection()
                panelController.showAtCursor()
            }
        }
        .keyboardShortcut("d", modifiers: .option)

        Button("OCR 截图翻译") {
            guard let coordinator = appDelegate.coordinator,
                  let panelController = appDelegate.panelController else { return }
            Task {
                await coordinator.ocrAndTranslate()
                if case .error = coordinator.state {
                    // Don't show panel on cancel
                } else {
                    panelController.showAtCursor()
                }
            }
        }
        .keyboardShortcut("s", modifiers: .option)

        Divider()

        SettingsLink {
            Text("设置...")
        }

        Divider()

        Button("退出 MoePeek") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
