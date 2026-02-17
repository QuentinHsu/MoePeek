import Defaults
import SwiftUI

/// First-launch onboarding view showing permission status and setup guidance.
struct OnboardingView: View {
    let permissionManager: PermissionManager
    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)

                Text("MoePeek")
                    .font(.title.bold())

                Text("菜单栏翻译工具，需要以下权限才能正常工作")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 24)
            .padding(.bottom, 20)

            // Permission cards
            VStack(spacing: 8) {
                PermissionCardView(
                    icon: "hand.raised",
                    title: "辅助功能",
                    description: "用于读取选中文本",
                    isGranted: permissionManager.isAccessibilityGranted,
                    onOpenSettings: { permissionManager.openAccessibilitySettings() }
                )

                PermissionCardView(
                    icon: "rectangle.dashed.badge.record",
                    title: "屏幕录制",
                    description: "用于 OCR 截图翻译",
                    isGranted: permissionManager.isScreenRecordingGranted,
                    onOpenSettings: { permissionManager.openScreenRecordingSettings() }
                )
            }
            .padding(.horizontal, 24)

            Spacer()

            // Footer
            VStack(spacing: 12) {
                Text("授权后状态会自动更新，无需重启应用")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Button {
                    Defaults[.hasCompletedOnboarding] = true
                    onComplete()
                } label: {
                    Text("开始使用")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 24)
        }
        .frame(width: 380, height: 400)
    }
}
