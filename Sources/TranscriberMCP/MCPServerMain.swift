import Foundation
import MCP
import TranscriberCore

@main
struct MCPServerMain {
    static func main() async throws {
        let server = Server(
            name: "transcriber-mcp",
            version: "0.1.0",
            capabilities: .init(
                resources: .init(subscribe: true, listChanged: false),
                tools: .init(listChanged: false)
            )
        )

        let sessionManager = SessionManager()
        await sessionManager.setServer(server)
        let handler = TranscriptionToolHandler(sessionManager: sessionManager)

        // Tool handlers
        await server.withMethodHandler(ListTools.self) { _ in
            ListTools.Result(tools: TranscriberTools.allTools)
        }

        await server.withMethodHandler(CallTool.self) { params in
            try await handler.handle(params)
        }

        // Resource handlers
        await server.withMethodHandler(ListResources.self) { _ in
            ListResources.Result(resources: [
                Resource(
                    name: "Live Transcript",
                    uri: "transcript://live",
                    description: "Current accumulated transcript text from active or last session",
                    mimeType: "text/plain"
                )
            ])
        }

        await server.withMethodHandler(ListResourceTemplates.self) { _ in
            ListResourceTemplates.Result(templates: [])
        }

        await server.withMethodHandler(ReadResource.self) { params in
            guard params.uri == "transcript://live" else {
                throw MCPError.invalidParams("Unknown resource: \(params.uri)")
            }
            let transcript = await sessionManager.liveTranscript
            return ReadResource.Result(contents: [
                .text(
                    transcript.isEmpty ? "(no transcript)" : transcript,
                    uri: params.uri,
                    mimeType: "text/plain"
                )
            ])
        }

        // Subscription handlers
        await server.withMethodHandler(ResourceSubscribe.self) { params in
            await sessionManager.subscribe(uri: params.uri)
            return Empty()
        }

        await server.withMethodHandler(ResourceUnsubscribe.self) { params in
            await sessionManager.unsubscribe(uri: params.uri)
            return Empty()
        }

        let transport = StdioTransport()
        try await server.start(transport: transport)
        await server.waitUntilCompleted()
    }
}
