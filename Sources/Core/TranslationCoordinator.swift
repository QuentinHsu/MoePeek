import AppKit
import Defaults

/// Central coordinator that orchestrates: text grabbing → language detection → translation → UI update.
@MainActor
@Observable
final class TranslationCoordinator {
    enum State: Sendable {
        case idle
        case grabbing
        case translating(sourceText: String)
        case streaming(sourceText: String, partial: String)
        case completed(TranslationResult)
        case error(String)
    }

    private(set) var state: State = .idle

    private let permissionManager: PermissionManager

    init(permissionManager: PermissionManager) {
        self.permissionManager = permissionManager
    }

    // MARK: - Public Actions

    /// Triggered by keyboard shortcut: grab selected text → translate.
    func translateSelection() async {
        guard permissionManager.isAccessibilityGranted else {
            state = .error("Accessibility permission not granted. Open Settings to enable it.")
            return
        }

        state = .grabbing

        guard let text = await TextSelectionManager.grabSelectedText() else {
            state = .error("No text selected. Select some text and try again.")
            return
        }

        await translate(text)
    }

    /// Triggered by OCR shortcut: screen capture → OCR → translate.
    func ocrAndTranslate() async {
        state = .grabbing

        do {
            let text = try await ScreenCaptureOCR.captureAndRecognize()
            await translate(text)
        } catch is OCRError {
            state = .idle // User cancelled capture — silent return
        } catch {
            state = .error("OCR failed: \(error.localizedDescription)")
        }
    }

    /// Translate arbitrary text (e.g. from manual input).
    func translate(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            state = .error("Empty text")
            return
        }

        state = .translating(sourceText: trimmed)

        let detectedLang = LanguageDetector.detect(trimmed)
        let targetLang = resolveTargetLanguage(detected: detectedLang)

        let service = resolveService()

        do {
            let result = try await performStreamingTranslation(
                text: trimmed, service: service,
                detectedLang: detectedLang, targetLang: targetLang
            )
            state = .completed(result)
        } catch let error as TranslationError where error.shouldFallback {
            await attemptFallbackTranslation(
                text: trimmed,
                detectedLang: detectedLang,
                targetLang: targetLang,
                originalError: error
            )
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func dismiss() {
        state = .idle
    }

    // MARK: - Private

    private func performStreamingTranslation(
        text: String,
        service: any TranslationService,
        detectedLang: String?,
        targetLang: String
    ) async throws -> TranslationResult {
        var accumulated = ""
        for try await chunk in service.translateStream(text, from: detectedLang, to: targetLang) {
            accumulated += chunk
            state = .streaming(sourceText: text, partial: accumulated)
        }
        guard !accumulated.isEmpty else {
            throw TranslationError.emptyResult
        }
        return TranslationResult(
            sourceText: text,
            translatedText: accumulated,
            sourceLang: detectedLang ?? "unknown",
            targetLang: targetLang,
            service: service.name
        )
    }

    private func attemptFallbackTranslation(
        text: String,
        detectedLang: String?,
        targetLang: String,
        originalError: TranslationError
    ) async {
        guard let apiKey = KeychainHelper.load(key: "openai_api_key"), !apiKey.isEmpty else {
            state = .error(originalError.localizedDescription)
            return
        }

        do {
            let result = try await performStreamingTranslation(
                text: text, service: OpenAITranslationService(),
                detectedLang: detectedLang, targetLang: targetLang
            )
            state = .completed(result)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func resolveTargetLanguage(detected: String?) -> String {
        let preferred = Defaults[.targetLanguage]

        // If detected language matches target, flip to English or Chinese
        guard let detected else { return preferred }

        if detected.hasPrefix("zh") && preferred.hasPrefix("zh") {
            return "en"
        }
        if detected == preferred {
            return detected.hasPrefix("zh") ? "en" : "zh-Hans"
        }

        return preferred
    }

    private func resolveService() -> any TranslationService {
        let preferred = Defaults[.preferredService]

        #if canImport(Translation)
        if preferred == "apple", #available(macOS 15.0, *) {
            return AppleTranslationService()
        }
        #endif

        return OpenAITranslationService()
    }
}
