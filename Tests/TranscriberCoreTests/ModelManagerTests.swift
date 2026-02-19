import Foundation
import Testing
@testable import TranscriberCore

/// Mock provider for testing ModelManager without real Speech framework.
struct MockSpeechModelProvider: SpeechModelProvider {
    var supported: [Locale]
    var installed: [Locale]
    var reserved: [Locale]
    var downloadShouldFail: Bool
    var reserveShouldFail: Bool

    init(
        supported: [Locale] = [Locale(identifier: "en-US"), Locale(identifier: "en-GB")],
        installed: [Locale] = [Locale(identifier: "en-US")],
        reserved: [Locale] = [],
        downloadShouldFail: Bool = false,
        reserveShouldFail: Bool = false
    ) {
        self.supported = supported
        self.installed = installed
        self.reserved = reserved
        self.downloadShouldFail = downloadShouldFail
        self.reserveShouldFail = reserveShouldFail
    }

    func supportedLocales() async -> [Locale] { supported }
    func installedLocales() async -> [Locale] { installed }
    func reservedLocales() async -> [Locale] { reserved }

    func downloadIfNeeded(for locale: Locale) async throws -> Progress? {
        if downloadShouldFail {
            throw TranscriberError.modelDownloadFailed("Mock download failure")
        }
        return nil
    }

    func reserve(locale: Locale) async throws {
        if reserveShouldFail {
            throw TranscriberError.localeNotSupported(locale.identifier)
        }
    }

    func release(locale: Locale) async {}
}

@Suite("ModelManager")
struct ModelManagerTests {

    @Test func ensureModelReturnsSupportedLocale() async throws {
        let provider = MockSpeechModelProvider()
        let manager = ModelManager(provider: provider)
        let locale = try await manager.ensureModel(for: Locale(identifier: "en-US"))
        #expect(locale.identifier == "en-US")
    }

    @Test func fallsBackWhenLocaleUnsupported() async throws {
        let provider = MockSpeechModelProvider(
            supported: [Locale(identifier: "en-US")]
        )
        let manager = ModelManager(provider: provider)
        // fr-FR not supported, should fallback to en-US
        let locale = try await manager.ensureModel(for: Locale(identifier: "fr-FR"))
        #expect(locale.identifier == "en-US")
    }

    @Test func throwsWhenNoFallbackAvailable() async throws {
        let provider = MockSpeechModelProvider(
            supported: [Locale(identifier: "zh-CN")]  // None of the fallbacks
        )
        let manager = ModelManager(provider: provider)

        do {
            _ = try await manager.ensureModel(for: Locale(identifier: "fr-FR"))
            Issue.record("Expected localeNotSupported error")
        } catch let error as TranscriberError {
            if case .localeNotSupported = error {
                // expected
            } else {
                Issue.record("Wrong error: \(error)")
            }
        }
    }

    @Test func skipsReserveIfAlreadyReserved() async throws {
        let provider = MockSpeechModelProvider(
            reserved: [Locale(identifier: "en-US")]
        )
        let manager = ModelManager(provider: provider)
        // Should not throw even though reserve would fail
        let locale = try await manager.ensureModel(for: Locale(identifier: "en-US"))
        #expect(locale.identifier == "en-US")
    }

    @Test func listsSupportedLocales() async throws {
        let provider = MockSpeechModelProvider(
            supported: [Locale(identifier: "en-US"), Locale(identifier: "ja-JP")]
        )
        let manager = ModelManager(provider: provider)
        let locales = await manager.supportedLocales()
        #expect(locales.count == 2)
    }

    @Test func downloadFailurePropagates() async throws {
        let provider = MockSpeechModelProvider(downloadShouldFail: true)
        let manager = ModelManager(provider: provider)

        do {
            _ = try await manager.ensureModel(for: Locale(identifier: "en-US"))
            Issue.record("Expected download failure")
        } catch let error as TranscriberError {
            if case .modelDownloadFailed = error {
                // expected
            } else {
                Issue.record("Wrong error: \(error)")
            }
        }
    }
}
