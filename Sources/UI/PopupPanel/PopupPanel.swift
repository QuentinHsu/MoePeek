import AppKit

/// A floating, non-activating panel for showing translation results near the cursor.
final class PopupPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: true
        )

        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Rounded corners
        contentView?.wantsLayer = true
        contentView?.layer?.cornerRadius = 12
        contentView?.layer?.masksToBounds = true
    }

    // Allow becoming key window so users can select/copy text within the panel.
    override var canBecomeKey: Bool { true }
}
