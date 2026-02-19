import ArgumentParser
import Foundation
import TranscriberCore

struct LiveCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "live",
        abstract: "Transcribe live microphone input"
    )

    @Option(name: .long, help: "Locale for speech recognition")
    var locale: String = "en-US"

    @Flag(name: .long, inversion: .prefixedNo, help: "Enable speaker diarization")
    var diarization: Bool = true

    @Option(name: .long, help: "Output format: jsonl or text")
    var format: String = "text"

    func run() async throws {
        let options = TranscriptionOptions(
            locale: Locale(identifier: locale),
            enableDiarization: diarization,
            enableVolatileResults: true
        )

        let engine = TranscriptionEngine()
        let stream = try await engine.startLive(options: options)

        let jsonlFormatter = JSONLinesFormatter()
        let textFormatter = TextFormatter()

        // Handle Ctrl+C
        let signalSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        signal(SIGINT, SIG_IGN)
        signalSource.setEventHandler {
            Task {
                try? await engine.stop()
            }
        }
        signalSource.resume()

        for await event in stream {
            let output: String
            switch format {
            case "jsonl":
                output = jsonlFormatter.format(event)
            default:
                output = textFormatter.format(event)
            }

            switch event {
            case .volatile:
                // Overwrite line for volatile results
                print("\r\(output)", terminator: "")
                fflush(stdout)
            case .final_:
                print("\r\(output)")
            case .diarization, .ended:
                print(output)
            }
        }

        signalSource.cancel()
    }
}
