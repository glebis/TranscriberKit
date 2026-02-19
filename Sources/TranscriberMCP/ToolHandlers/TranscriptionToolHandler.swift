import Foundation
import MCP
import TranscriberCore

struct TranscriptionToolHandler {
    let sessionManager: SessionManager

    func handle(_ params: CallTool.Parameters) async throws -> CallTool.Result {
        switch params.name {
        case "start_transcription":
            return try await handleStartTranscription(params)
        case "stop_transcription":
            return try await handleStopTranscription()
        case "transcribe_file":
            return try await handleTranscribeFile(params)
        case "get_status":
            return await handleGetStatus()
        default:
            throw MCPError.invalidParams("Unknown tool: \(params.name)")
        }
    }

    private func handleStartTranscription(_ params: CallTool.Parameters) async throws
        -> CallTool.Result
    {
        let locale = params.arguments?["locale"]?.stringValue ?? "en-US"
        let enableDiarization = params.arguments?["enable_diarization"]?.boolValue ?? true
        let maxSpeakers = params.arguments?["max_speakers"]?.intValue ?? 10

        let options = TranscriptionOptions.forMCP(
            locale: Locale(identifier: locale),
            enableDiarization: enableDiarization,
            maxSpeakers: maxSpeakers
        )

        let message = try await sessionManager.startLive(options: options)
        return CallTool.Result(content: [.text(message)])
    }

    private func handleStopTranscription() async throws -> CallTool.Result {
        let result = try await sessionManager.stop()
        let formatter = JSONLinesFormatter()
        let json = formatter.formatResult(result)
        return CallTool.Result(content: [.text(json)])
    }

    private func handleTranscribeFile(_ params: CallTool.Parameters) async throws
        -> CallTool.Result
    {
        guard let path = params.arguments?["path"]?.stringValue else {
            throw MCPError.invalidParams("Missing required parameter: path")
        }

        let locale = params.arguments?["locale"]?.stringValue ?? "en-US"
        let enableDiarization = params.arguments?["enable_diarization"]?.boolValue ?? true

        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else {
            return CallTool.Result(
                content: [.text("Error: File not found: \(path)")],
                isError: true
            )
        }

        let options = TranscriptionOptions.forMCP(
            locale: Locale(identifier: locale),
            enableDiarization: enableDiarization
        )

        let result = try await sessionManager.transcribeFile(url: url, options: options)
        let formatter = JSONLinesFormatter()
        let json = formatter.formatResult(result)
        return CallTool.Result(content: [.text(json)])
    }

    private func handleGetStatus() async -> CallTool.Result {
        let status = await sessionManager.getStatus()
        return CallTool.Result(content: [.text(status)])
    }
}
