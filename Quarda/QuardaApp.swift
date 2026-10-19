import SwiftData
import SwiftUI

@main
struct QuardaApp: App {
    private let modelContainer: ModelContainer
    private let mcpServer: MCPServer?

    init() {
        modelContainer = AppDataStore.makeModelContainer()

        let server = MCPServer(
            router: MCPRouter(tools: TaskToolHandler(container: modelContainer))
        )
        do {
            try server.start()
            mcpServer = server
        } catch {
            print("MCP server unavailable: \(error.localizedDescription)")
            mcpServer = nil
        }
    }

    var body: some Scene {
        WindowGroup {
            MatrixView()
        }
        .modelContainer(modelContainer)
        .defaultSize(width: 1_080, height: 760)
        .windowResizability(.contentMinSize)
        .windowStyle(.hiddenTitleBar)
    }
}
