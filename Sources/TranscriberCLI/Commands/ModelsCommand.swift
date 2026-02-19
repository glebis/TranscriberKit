import ArgumentParser
import Foundation
import Speech
import TranscriberCore

struct ModelsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "models",
        abstract: "List and manage speech recognition models"
    )

    @Option(name: .long, help: "Download model for a specific locale")
    var download: String?

    @available(macOS 26, *)
    func run() async throws {
        let manager = ModelManager(provider: SystemSpeechModelProvider())

        if let downloadLocale = download {
            print("Downloading model for \(downloadLocale)...")
            let locale = Locale(identifier: downloadLocale)
            let reserved = try await manager.ensureModel(for: locale)
            print("Model ready for \(reserved.identifier)")
            return
        }

        // List models
        let supported = await manager.supportedLocales()
        let installed = await manager.installedLocales()

        print("Supported locales (\(supported.count)):")
        for locale in supported {
            let isInstalled = installed.contains {
                $0.identifier(.bcp47) == locale.identifier(.bcp47)
            }
            let marker = isInstalled ? "[installed]" : "[available]"
            print("  \(locale.identifier(.bcp47)) \(marker)")
        }

        if supported.isEmpty {
            print("  (No supported locales found. Ensure macOS 26+ and Speech framework are available.)")
        }
    }
}
