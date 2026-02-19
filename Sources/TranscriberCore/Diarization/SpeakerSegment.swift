import Foundation

/// A segment of audio attributed to a specific speaker.
public struct SpeakerSegment: Sendable, Codable, Equatable {
    public var speakerId: Int
    public var startTime: TimeInterval
    public var endTime: TimeInterval
    public var text: String?

    public init(
        speakerId: Int,
        startTime: TimeInterval,
        endTime: TimeInterval,
        text: String? = nil
    ) {
        self.speakerId = speakerId
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
    }

    public var duration: TimeInterval {
        endTime - startTime
    }
}
