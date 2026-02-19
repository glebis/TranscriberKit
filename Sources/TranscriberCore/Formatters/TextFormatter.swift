import Foundation

/// Formats TranscriptionEvents as human-readable plain text.
public struct TextFormatter: Sendable {

    public init() {}

    public func format(_ event: TranscriptionEvent) -> String {
        switch event {
        case .volatile(let result):
            return "... \(result.text)"
        case .final_(let result):
            return result.text
        case .diarization(let segments):
            return segments.map { seg in
                let speaker = "Speaker \(seg.speakerId)"
                let time = formatTime(seg.startTime) + "-" + formatTime(seg.endTime)
                let text = seg.text ?? ""
                return "[\(time)] \(speaker): \(text)"
            }.joined(separator: "\n")
        case .ended(let reason):
            switch reason {
            case .completed:
                return "[Transcription complete]"
            case .cancelled:
                return "[Transcription cancelled]"
            case .error(let msg):
                return "[Error: \(msg)]"
            }
        }
    }

    public func formatResult(_ result: TranscriptionResult) -> String {
        var output = result.text
        if !result.speakerSegments.isEmpty {
            output += "\n\n--- Speaker segments ---\n"
            for seg in result.speakerSegments {
                let time = formatTime(seg.startTime) + "-" + formatTime(seg.endTime)
                output += "[\(time)] Speaker \(seg.speakerId): \(seg.text ?? "")\n"
            }
        }
        return output
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
