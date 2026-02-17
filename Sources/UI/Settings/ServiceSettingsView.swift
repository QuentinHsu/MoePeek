import Defaults
import SwiftUI

#if canImport(Translation)
import Translation
#endif

struct ServiceSettingsView: View {
    @Default(.openAIBaseURL) private var baseURL
    @Default(.openAIModel) private var model
    @Default(.preferredService) private var preferredService
    @Default(.systemPromptTemplate) private var systemPrompt

    @State private var apiKey: String = KeychainHelper.load(key: "openai_api_key") ?? ""

    private var isAppleTranslationAvailable: Bool {
        if #available(macOS 15.0, *) {
            return true
        }
        return false
    }

    var body: some View {
        Form {
            Section("Preferred Service") {
                Picker("Default Service:", selection: $preferredService) {
                    Text("OpenAI Compatible").tag("openai")
                    if isAppleTranslationAvailable {
                        Text("Apple Translation").tag("apple")
                    }
                }
            }

            Section("OpenAI Compatible API") {
                TextField("Base URL:", text: $baseURL)
                    .textFieldStyle(.roundedBorder)

                TextField("Model:", text: $model)
                    .textFieldStyle(.roundedBorder)

                SecureField("API Key:", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: apiKey) { _, newValue in
                        if newValue.isEmpty {
                            KeychainHelper.delete(key: "openai_api_key")
                        } else {
                            KeychainHelper.save(key: "openai_api_key", value: newValue)
                        }
                    }

                DisclosureGroup("System Prompt") {
                    TextEditor(text: $systemPrompt)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 80)
                    Text("Use {targetLang} as placeholder for target language.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if isAppleTranslationAvailable {
                Section("Apple Translation") {
                    Text("Available on this system (macOS 15+). No API key needed.")
                        .foregroundStyle(.secondary)
                        .font(.callout)

                    if #available(macOS 15.0, *) {
                        LanguageDownloadView()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Language Download Management

#if canImport(Translation)
@available(macOS 15.0, *)
struct LanguageDownloadView: View {
    private enum PairStatus {
        case checking
        case installed
        case needsDownload
        case unsupported
        case unknown

        var label: String {
            switch self {
            case .checking: "Checking…"
            case .installed: "Installed"
            case .needsDownload: "Needs download"
            case .unsupported: "Unsupported"
            case .unknown: "Unknown"
            }
        }

        var color: Color {
            self == .installed ? .green : .secondary
        }
    }

    private static let languages: [(String, String)] = [
        ("en", "English"),
        ("zh-Hans", "Chinese (Simplified)"),
        ("zh-Hant", "Chinese (Traditional)"),
        ("ja", "Japanese"),
        ("ko", "Korean"),
        ("fr", "French"),
        ("de", "German"),
        ("es", "Spanish"),
        ("pt-BR", "Portuguese (Brazil)"),
        ("ru", "Russian"),
        ("ar", "Arabic"),
        ("it", "Italian"),
        ("th", "Thai"),
        ("vi", "Vietnamese"),
    ]

    @State private var selectedSource = "en"
    @State private var selectedTarget = "zh-Hans"
    @State private var pairStatus: PairStatus?
    @State private var downloadConfiguration: TranslationSession.Configuration?

    private var selectionId: String { "\(selectedSource)-\(selectedTarget)" }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Language Download")
                .font(.headline)

            HStack {
                Picker("From:", selection: $selectedSource) {
                    ForEach(Self.languages, id: \.0) { code, name in
                        Text(name).tag(code)
                    }
                }
                .frame(maxWidth: 200)

                Picker("To:", selection: $selectedTarget) {
                    ForEach(Self.languages, id: \.0) { code, name in
                        Text(name).tag(code)
                    }
                }
                .frame(maxWidth: 200)
            }

            HStack {
                Button("Check & Download") {
                    downloadConfiguration = .init(
                        source: Locale.Language(identifier: selectedSource),
                        target: Locale.Language(identifier: selectedTarget)
                    )
                }

                if let pairStatus {
                    Text(pairStatus.label)
                        .font(.callout)
                        .foregroundStyle(pairStatus.color)
                }
            }
        }
        .task(id: selectionId) {
            pairStatus = .checking
            let availability = LanguageAvailability()
            let source = Locale.Language(identifier: selectedSource)
            let target = Locale.Language(identifier: selectedTarget)
            let status = await availability.status(from: source, to: target)
            pairStatus = switch status {
            case .installed: .installed
            case .supported: .needsDownload
            case .unsupported: .unsupported
            @unknown default: .unknown
            }
        }
        .translationTask(downloadConfiguration) { session in
            do {
                try await session.prepareTranslation()
                pairStatus = .installed
            } catch {
                let availability = LanguageAvailability()
                let source = Locale.Language(identifier: selectedSource)
                let target = Locale.Language(identifier: selectedTarget)
                let status = await availability.status(from: source, to: target)
                pairStatus = status == .installed ? .installed : .needsDownload
            }
        }
    }
}
#endif
