import Foundation

/// Formats TranscriptionEvents as JSON Lines (one JSON object per line).
public struct JSONLinesFormatter: Sendable {
    private let encoder: JSONEncoder

    public init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
    }

    public func format(_ event: TranscriptionEvent) -> String {
        guard let data = try? encoder.encode(event),
              let line = String(data: data, encoding: .utf8)
        else {
            return "{\"error\":\"encoding_failed\"}"
        }
        return line
    }

    public func formatResult(_ result: TranscriptionResult) -> String {
        guard let data = try? encoder.encode(result),
              let json = String(data: data, encoding: .utf8)
        else {
            return "{\"error\":\"encoding_failed\"}"
        }
        return json
    }
}
