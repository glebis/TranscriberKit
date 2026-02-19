import Foundation
import MCP

enum TranscriberTools {
    static let startTranscription = Tool(
        name: "start_transcription",
        description: "Begin live microphone recording for speech transcription. Returns immediately; use stop_transcription to get the full transcript.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "locale": .object([
                    "type": .string("string"),
                    "description": .string("Speech recognition locale (e.g. en-US, de-DE)"),
                ]),
                "enable_diarization": .object([
                    "type": .string("boolean"),
                    "description": .string("Enable speaker identification (default: true)"),
                ]),
                "max_speakers": .object([
                    "type": .string("number"),
                    "description": .string(
                        "Maximum number of speakers to identify (default: 10)"),
                ]),
            ]),
        ])
    )

    static let stopTranscription = Tool(
        name: "stop_transcription",
        description: "Stop live recording and return the full transcript with optional speaker diarization results.",
        inputSchema: .object(["type": .string("object")])
    )

    static let transcribeFile = Tool(
        name: "transcribe_file",
        description: "Transcribe an audio file. Supports WAV, M4A, MP3, CAF formats.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "path": .object([
                    "type": .string("string"),
                    "description": .string("Absolute path to the audio file"),
                ]),
                "locale": .object([
                    "type": .string("string"),
                    "description": .string("Speech recognition locale (e.g. en-US)"),
                ]),
                "enable_diarization": .object([
                    "type": .string("boolean"),
                    "description": .string("Enable speaker identification (default: true)"),
                ]),
            ]),
            "required": .array([.string("path")]),
        ])
    )

    static let getStatus = Tool(
        name: "get_status",
        description: "Get the current transcription engine state: idle, recording, transcribing, or processing.",
        inputSchema: .object(["type": .string("object")])
    )

    static let allTools: [Tool] = [
        startTranscription,
        stopTranscription,
        transcribeFile,
        getStatus,
    ]
}
