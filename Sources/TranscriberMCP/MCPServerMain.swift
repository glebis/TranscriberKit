import Foundation
import MCP
import TranscriberCore

@main
struct MCPServerMain {
    static func main() async throws {
        let server = Server(
            name: "transcriber-mcp",
            version: "0.1.0",
            capabilities: .init(tools: .init(listChanged: false))
        )

        let sessionManager = SessionManager()
        let handler = TranscriptionToolHandler(sessionManager: sessionManager)

        await server.withMethodHandler(ListTools.self) { _ in
            ListTools.Result(tools: TranscriberTools.allTools)
        }

        await server.withMethodHandler(CallTool.self) { params in
            try await handler.handle(params)
        }

        let transport = StdioTransport()
        try await server.start(transport: transport)
        await server.waitUntilCompleted()
    }
}
