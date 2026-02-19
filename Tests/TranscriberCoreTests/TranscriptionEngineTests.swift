import AVFoundation
import Foundation
import Testing
@testable import TranscriberCore

@Suite("TranscriptionEngine")
struct TranscriptionEngineTests {

    /// Create an engine that always uses the mock session (no Speech framework needed).
    private func makeMockEngine() -> TranscriptionEngine {
        let engine = TranscriptionEngine()
        // Synchronous property set not possible on actor from outside,
        // so we set it via the test helper below
        return engine
    }

    private func withMockEngine(_ body: (TranscriptionEngine) async throws -> Void) async throws {
        let engine = TranscriptionEngine()
        await engine.setForceMock(true)
        try await body(engine)
    }

    @Test func initialStateIsIdle() async throws {
        let engine = TranscriptionEngine()
        let state = await engine.getStatus()
        #expect(state == .idle)
    }

    @Test func startWithSourceChangesState() async throws {
        try await withMockEngine { engine in
            let source = MockAudioSource(bufferCount: 2)
            let stream = try await engine.startWithSource(source)

            let state = await engine.getStatus()
            #expect(state == .recording)

            for await _ in stream {}

            let finalState = await engine.getStatus()
            #expect(finalState == .idle)
        }
    }

    @Test func cannotStartTwoSessions() async throws {
        try await withMockEngine { engine in
            let source1 = MockAudioSource(bufferCount: 100)
            _ = try await engine.startWithSource(source1)

            let source2 = MockAudioSource(bufferCount: 1)
            do {
                _ = try await engine.startWithSource(source2)
                Issue.record("Expected sessionAlreadyActive error")
            } catch let error as TranscriberError {
                #expect(error == .sessionAlreadyActive)
            }
        }
    }

    @Test func stopWithoutStartThrows() async throws {
        let engine = TranscriptionEngine()
        do {
            try await engine.stop()
            Issue.record("Expected noActiveSession error")
        } catch let error as TranscriberError {
            #expect(error == .noActiveSession)
        }
    }

    @Test func collectsEventsFromSession() async throws {
        try await withMockEngine { engine in
            let source = MockAudioSource(bufferCount: 2)
            let stream = try await engine.startWithSource(source)

            for await _ in stream {}

            let events = await engine.getCollectedEvents()
            // 2 volatile + 2 final + 1 ended = 5
            #expect(events.count == 5)
        }
    }

    @Test func buildsResultFromEvents() async throws {
        try await withMockEngine { engine in
            let source = MockAudioSource(bufferCount: 2)
            let stream = try await engine.startWithSource(source)

            for await _ in stream {}

            let result = await engine.buildResult(locale: "en-US")
            #expect(result.text == "segment 0segment 1")
            #expect(result.segments.count == 2)
            #expect(result.locale == "en-US")
        }
    }

    @Test func resetClearsState() async throws {
        try await withMockEngine { engine in
            let source = MockAudioSource(bufferCount: 1)
            let stream = try await engine.startWithSource(source)
            for await _ in stream {}

            await engine.reset()
            let events = await engine.getCollectedEvents()
            #expect(events.isEmpty)
            let state = await engine.getStatus()
            #expect(state == .idle)
        }
    }

    @Test func canStartAfterPreviousCompletes() async throws {
        try await withMockEngine { engine in
            let source1 = MockAudioSource(bufferCount: 1)
            let stream1 = try await engine.startWithSource(source1)
            for await _ in stream1 {}

            let source2 = MockAudioSource(bufferCount: 1)
            let stream2 = try await engine.startWithSource(source2)
            for await _ in stream2 {}

            let events = await engine.getCollectedEvents()
            #expect(!events.isEmpty)
        }
    }

    @Test func fileTranscriptionChangesState() async throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1600)!
        buffer.frameLength = 1600
        if let data = buffer.floatChannelData {
            for i in 0..<1600 { data[0][i] = sinf(Float(i) * 0.1) }
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        defer { try? FileManager.default.removeItem(at: url) }

        try await withMockEngine { engine in
            let stream = try await engine.startFile(url: url)
            for await _ in stream {}

            let state = await engine.getStatus()
            #expect(state == .idle)
        }
    }
}
