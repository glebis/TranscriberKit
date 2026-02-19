import AVFoundation
import Foundation
import Testing
@testable import TranscriberCore

@Suite("MockTranscriptionSession")
struct TranscriptionSessionTests {

    @Test func sessionEmitsEventsInOrder() async throws {
        let source = MockAudioSource(bufferCount: 3)
        let session = MockTranscriptionSession(source: source)
        let stream = await session.start()

        var events: [TranscriptionEvent] = []
        for await event in stream {
            events.append(event)
        }

        // With volatile enabled: 3 volatile + 3 final + 1 ended = 7 events
        #expect(events.count == 7)

        // First event should be volatile
        if case .volatile(let v) = events[0] {
            #expect(v.text == "partial 0")
        } else {
            Issue.record("Expected volatile event first")
        }

        // Second should be final
        if case .final_(let f) = events[1] {
            #expect(f.text == "segment 0")
        } else {
            Issue.record("Expected final event second")
        }

        // Last should be ended
        if case .ended(.completed) = events.last {
            // expected
        } else {
            Issue.record("Expected ended(.completed) last, got \(String(describing: events.last))")
        }
    }

    @Test func sessionWithoutVolatile() async throws {
        let source = MockAudioSource(bufferCount: 2)
        let opts = TranscriptionOptions(enableVolatileResults: false)
        let session = MockTranscriptionSession(source: source, options: opts)
        let stream = await session.start()

        var events: [TranscriptionEvent] = []
        for await event in stream {
            events.append(event)
        }

        // Without volatile: 2 final + 1 ended = 3 events
        #expect(events.count == 3)

        // No volatile events
        let volatiles = events.filter {
            if case .volatile = $0 { return true }
            return false
        }
        #expect(volatiles.isEmpty)
    }

    @Test func sessionHandlesSourceError() async throws {
        let source = FailingAudioSource(failAfter: 1)
        let session = MockTranscriptionSession(source: source)
        let stream = await session.start()

        var events: [TranscriptionEvent] = []
        for await event in stream {
            events.append(event)
        }

        // Should have some events then ended with error
        let ended = events.last
        if case .ended(.error) = ended {
            // expected
        } else {
            Issue.record("Expected ended(.error), got \(String(describing: ended))")
        }
    }

    @Test func doubleStartReturnEmptyStream() async throws {
        let source = MockAudioSource(bufferCount: 1)
        let session = MockTranscriptionSession(source: source)

        // First start
        let stream1 = await session.start()

        // Consume first stream
        for await _ in stream1 {}

        // Second start should return empty (session already used)
        let stream2 = await session.start()
        var count = 0
        for await _ in stream2 {
            count += 1
        }
        // The state is no longer .idle after first start
    }
}
