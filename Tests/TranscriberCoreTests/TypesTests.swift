import Foundation
import Testing
@testable import TranscriberCore

@Suite("TranscriptionEvent encoding/decoding")
struct TranscriptionEventTests {

    @Test func volatileEventRoundTrips() throws {
        let event = TranscriptionEvent.volatile(.init(text: "hello", timestamp: 1.5))
        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(TranscriptionEvent.self, from: data)
        #expect(decoded == event)
    }

    @Test func finalEventRoundTrips() throws {
        let event = TranscriptionEvent.final_(.init(text: "hello world", startTime: 0.0, endTime: 2.5))
        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(TranscriptionEvent.self, from: data)
        #expect(decoded == event)
    }

    @Test func diarizationEventRoundTrips() throws {
        let segments = [
            SpeakerSegment(speakerId: 0, startTime: 0, endTime: 5, text: "Speaker A"),
            SpeakerSegment(speakerId: 1, startTime: 5, endTime: 10, text: "Speaker B"),
        ]
        let event = TranscriptionEvent.diarization(segments)
        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(TranscriptionEvent.self, from: data)
        #expect(decoded == event)
    }

    @Test func endedEventRoundTrips() throws {
        for reason in [
            TranscriptionEvent.EndReason.completed,
            .cancelled,
            .error("something broke"),
        ] {
            let event = TranscriptionEvent.ended(reason)
            let data = try JSONEncoder().encode(event)
            let decoded = try JSONDecoder().decode(TranscriptionEvent.self, from: data)
            #expect(decoded == event)
        }
    }
}

@Suite("TranscriptionOptions defaults")
struct TranscriptionOptionsTests {

    @Test func defaultLocaleIsEnUS() {
        let opts = TranscriptionOptions()
        #expect(opts.locale.identifier == "en-US" || opts.locale.identifier(.bcp47) == "en-US")
    }

    @Test func defaultDiarizationEnabled() {
        let opts = TranscriptionOptions()
        #expect(opts.enableDiarization == true)
        #expect(opts.maxSpeakers == 10)
    }

    @Test func defaultVolatileEnabled() {
        let opts = TranscriptionOptions()
        #expect(opts.enableVolatileResults == true)
    }

    @Test func mcpOptionsDisableVolatile() {
        let opts = TranscriptionOptions.forMCP()
        #expect(opts.enableVolatileResults == false)
    }
}

@Suite("SpeakerSegment")
struct SpeakerSegmentTests {

    @Test func durationComputed() {
        let seg = SpeakerSegment(speakerId: 0, startTime: 1.0, endTime: 3.5)
        #expect(seg.duration == 2.5)
    }

    @Test func codableRoundTrip() throws {
        let seg = SpeakerSegment(speakerId: 2, startTime: 0, endTime: 10, text: "hello")
        let data = try JSONEncoder().encode(seg)
        let decoded = try JSONDecoder().decode(SpeakerSegment.self, from: data)
        #expect(decoded == seg)
    }
}

@Suite("TranscriptionResult")
struct TranscriptionResultTests {

    @Test func emptyResultDefaults() {
        let result = TranscriptionResult()
        #expect(result.text == "")
        #expect(result.segments.isEmpty)
        #expect(result.speakerSegments.isEmpty)
        #expect(result.duration == 0)
        #expect(result.locale == "en-US")
    }

    @Test func codableRoundTrip() throws {
        let result = TranscriptionResult(
            text: "Hello world",
            segments: [.init(text: "Hello", startTime: 0, endTime: 0.5)],
            speakerSegments: [.init(speakerId: 0, startTime: 0, endTime: 1)],
            duration: 1.0,
            locale: "en-US"
        )
        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(TranscriptionResult.self, from: data)
        #expect(decoded == result)
    }
}

@Suite("TranscriberError")
struct TranscriberErrorTests {

    @Test func errorDescriptions() {
        let cases: [(TranscriberError, String)] = [
            (.localeNotSupported("fr-FR"), "Locale not supported: fr-FR"),
            (.sessionAlreadyActive, "A transcription session is already active"),
            (.noActiveSession, "No active transcription session"),
            (.audioFileNotFound("/tmp/x.wav"), "Audio file not found: /tmp/x.wav"),
        ]
        for (error, expected) in cases {
            #expect(error.description == expected)
        }
    }
}
