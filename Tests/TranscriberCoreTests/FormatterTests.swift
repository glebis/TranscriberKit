import Foundation
import Testing
@testable import TranscriberCore

@Suite("JSONLinesFormatter")
struct JSONLinesFormatterTests {
    let formatter = JSONLinesFormatter()

    @Test func formatsVolatileEvent() throws {
        let event = TranscriptionEvent.volatile(.init(text: "hello", timestamp: 1.0))
        let line = formatter.format(event)
        #expect(line.contains("\"hello\""))
        #expect(line.contains("volatile"))
        // Should be valid JSON
        _ = try JSONSerialization.jsonObject(with: Data(line.utf8))
    }

    @Test func formatsFinalEvent() throws {
        let event = TranscriptionEvent.final_(.init(text: "world", startTime: 0, endTime: 1))
        let line = formatter.format(event)
        #expect(line.contains("\"world\""))
        _ = try JSONSerialization.jsonObject(with: Data(line.utf8))
    }

    @Test func formatsDiarizationEvent() throws {
        let segments = [SpeakerSegment(speakerId: 0, startTime: 0, endTime: 5)]
        let event = TranscriptionEvent.diarization(segments)
        let line = formatter.format(event)
        #expect(line.contains("diarization"))
        _ = try JSONSerialization.jsonObject(with: Data(line.utf8))
    }

    @Test func formatsEndedEvent() throws {
        let event = TranscriptionEvent.ended(.completed)
        let line = formatter.format(event)
        #expect(line.contains("ended"))
        _ = try JSONSerialization.jsonObject(with: Data(line.utf8))
    }

    @Test func roundTripThroughJSON() throws {
        let event = TranscriptionEvent.final_(.init(text: "test", startTime: 1.5, endTime: 3.0))
        let line = formatter.format(event)
        let decoded = try JSONDecoder().decode(
            TranscriptionEvent.self,
            from: Data(line.utf8)
        )
        #expect(decoded == event)
    }

    @Test func formatsResult() throws {
        let result = TranscriptionResult(
            text: "Hello world",
            segments: [.init(text: "Hello", startTime: 0, endTime: 0.5)],
            duration: 0.5,
            locale: "en-US"
        )
        let json = formatter.formatResult(result)
        #expect(json.contains("Hello world"))
        _ = try JSONSerialization.jsonObject(with: Data(json.utf8))
    }
}

@Suite("TextFormatter")
struct TextFormatterTests {
    let formatter = TextFormatter()

    @Test func formatsVolatile() {
        let event = TranscriptionEvent.volatile(.init(text: "thinking", timestamp: 0))
        let text = formatter.format(event)
        #expect(text == "... thinking")
    }

    @Test func formatsFinal() {
        let event = TranscriptionEvent.final_(.init(text: "Hello world", startTime: 0, endTime: 1))
        let text = formatter.format(event)
        #expect(text == "Hello world")
    }

    @Test func formatsDiarization() {
        let segments = [
            SpeakerSegment(speakerId: 0, startTime: 0, endTime: 65, text: "First speaker"),
            SpeakerSegment(speakerId: 1, startTime: 65, endTime: 130, text: "Second speaker"),
        ]
        let event = TranscriptionEvent.diarization(segments)
        let text = formatter.format(event)
        #expect(text.contains("Speaker 0"))
        #expect(text.contains("Speaker 1"))
        #expect(text.contains("[00:00-01:05]"))
        #expect(text.contains("[01:05-02:10]"))
    }

    @Test func formatsEndedCompleted() {
        let text = formatter.format(.ended(.completed))
        #expect(text == "[Transcription complete]")
    }

    @Test func formatsEndedError() {
        let text = formatter.format(.ended(.error("oops")))
        #expect(text == "[Error: oops]")
    }

    @Test func formatsResultWithSpeakers() {
        let result = TranscriptionResult(
            text: "Hello",
            speakerSegments: [
                SpeakerSegment(speakerId: 0, startTime: 0, endTime: 5, text: "Hello")
            ]
        )
        let text = formatter.formatResult(result)
        #expect(text.contains("Hello"))
        #expect(text.contains("Speaker 0"))
        #expect(text.contains("--- Speaker segments ---"))
    }

    @Test func formatsResultWithoutSpeakers() {
        let result = TranscriptionResult(text: "Just text")
        let text = formatter.formatResult(result)
        #expect(text == "Just text")
        #expect(!text.contains("Speaker"))
    }
}
