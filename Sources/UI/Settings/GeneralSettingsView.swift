import Defaults
import KeyboardShortcuts
import ServiceManagement
import SwiftUI

struct GeneralSettingsView: View {
    @Default(.targetLanguage) private var targetLanguage
    @Default(.isAutoDetectEnabled) private var isAutoDetectEnabled
    @Default(.showInDock) private var showInDock
    @Default(.popupDefaultWidth) private var popupDefaultWidth
    @Default(.popupDefaultHeight) private var popupDefaultHeight
    @Default(.sourceLanguage) private var sourceLanguage
    @Default(.isLanguageDetectionEnabled) private var isLanguageDetectionEnabled
    @Default(.detectionConfidenceThreshold) private var confidenceThreshold

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("快捷键") {
                KeyboardShortcuts.Recorder("选中翻译:", name: .translateSelection)
                KeyboardShortcuts.Recorder("截图 OCR:", name: .ocrScreenshot)
                KeyboardShortcuts.Recorder("手动翻译:", name: .inputTranslation)
                KeyboardShortcuts.Recorder("剪贴翻译:", name: .clipboardTranslation)
            }

            Section("通用") {
                Picker("目标语言:", selection: $targetLanguage) {
                    ForEach(SupportedLanguages.all, id: \.code) { code, name in
                        Text(name).tag(code)
                    }
                }

                Toggle("选中文字自动翻译", isOn: $isAutoDetectEnabled)

                Toggle("登录时启动", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = !newValue // Revert on failure
                        }
                    }

                Toggle("在程序坞中显示图标", isOn: $showInDock)
                    .onChange(of: showInDock) { _, newValue in
                        NSApp.setActivationPolicy(newValue ? .regular : .accessory)
                        if !newValue {
                            NSApp.activate(ignoringOtherApps: true)
                        }
                    }
            }

            Section("语言检测") {
                Toggle("自动检测源语言", isOn: $isLanguageDetectionEnabled)
                    .onChange(of: isLanguageDetectionEnabled) { _, newValue in
                        if !newValue, sourceLanguage == "auto" {
                            sourceLanguage = Defaults[.targetLanguage].hasPrefix("zh") ? "en" : "zh-Hans"
                        }
                    }

                if isLanguageDetectionEnabled {
                    Picker("偏好源语言:", selection: $sourceLanguage) {
                        Text("无偏好").tag("auto")
                        ForEach(SupportedLanguages.all, id: \.code) { code, name in
                            Text(name).tag(code)
                        }
                    }

                    LabeledContent("检测灵敏度: \(confidenceThreshold, specifier: "%.1f")") {
                        Slider(value: $confidenceThreshold, in: 0.1...0.8, step: 0.1)
                    }
                    Text("较低 = 更积极检测（可能不准）；较高 = 更保守（可能返回未知）")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Picker("源语言:", selection: $sourceLanguage) {
                        ForEach(SupportedLanguages.all, id: \.code) { code, name in
                            Text(name).tag(code)
                        }
                    }
                }
            }

            Section("弹出面板") {
                LabeledContent("默认宽度: \(popupDefaultWidth)") {
                    Slider(
                        value: Binding(
                            get: { Double(popupDefaultWidth) },
                            set: { popupDefaultWidth = Int($0) }
                        ),
                        in: 280...800,
                        step: 10
                    )
                }

                LabeledContent("默认高度: \(popupDefaultHeight)") {
                    Slider(
                        value: Binding(
                            get: { Double(popupDefaultHeight) },
                            set: { popupDefaultHeight = Int($0) }
                        ),
                        in: 200...800,
                        step: 10
                    )
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
