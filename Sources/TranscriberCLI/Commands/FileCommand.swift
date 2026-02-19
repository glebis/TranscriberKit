import ArgumentParser
import Foundation
import TranscriberCore

struct FileCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "file",
        abstract: "Transcribe an audio file"
    )

    @Argument(help: "Path to audio file")
    var path: String

    @Option(name: .long, help: "Locale for speech recognition")
    var locale: String = "en-US"

    @Flag(name: .long, inversion: .prefixedNo, help: "Enable speaker diarization")
    var diarization: Bool = true

    @Option(name: .long, help: "Output format: jsonl or text")
    var format: String = "text"

    func run() async throws {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else {
            throw ValidationError("File not found: \(path)")
        }

        let options = TranscriptionOptions(
            locale: Locale(identifier: locale),
            enableDiarization: diarization,
            enableVolatileResults: format == "jsonl"
        )

        let engine = TranscriptionEngine()
        let stream = try await engine.startFile(url: url, options: options)

        let jsonlFormatter = JSONLinesFormatter()
        let textFormatter = TextFormatter()

        for await event in stream {
            let output: String
            switch format {
            case "jsonl":
                output = jsonlFormatter.format(event)
                print(output)
            default:
                output = textFormatter.format(event)
                switch event {
                case .volatile:
                    print("\r\(output)", terminator: "")
                    fflush(stdout)
                default:
                    print(output)
                }
            }
        }
    }
}
