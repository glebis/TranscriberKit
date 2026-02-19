import ArgumentParser

@main
struct TranscriberCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "transcriber",
        abstract: "On-device speech transcription using Apple Speech framework",
        subcommands: [LiveCommand.self, FileCommand.self, ModelsCommand.self]
    )
}
