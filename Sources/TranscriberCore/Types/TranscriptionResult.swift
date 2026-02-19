import Foundation

/// Complete result of a transcription session.
public struct TranscriptionResult: Sendable, Codable, Equatable {
    public var text: String
    public var segments: [Segment]
    public var speakerSegments: [SpeakerSegment]
    public var duration: TimeInterval
    public var locale: String

    public struct Segment: Sendable, Codable, Equatable {
        public var text: String
        public var startTime: TimeInterval
        public var endTime: TimeInterval

        public init(text: String, startTime: TimeInterval, endTime: TimeInterval) {
            self.text = text
            self.startTime = startTime
            self.endTime = endTime
        }
    }

    public init(
        text: String = "",
        segments: [Segment] = [],
        speakerSegments: [SpeakerSegment] = [],
        duration: TimeInterval = 0,
        locale: String = "en-US"
    ) {
        self.text = text
        self.segments = segments
        self.speakerSegments = speakerSegments
        self.duration = duration
        self.locale = locale
    }
}
