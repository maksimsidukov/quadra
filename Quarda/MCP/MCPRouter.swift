import Foundation

@MainActor
protocol MCPToolHandling: Sendable {
    func listTasks(includeCompleted: Bool) throws -> JSONValue
    func addTask(title: String, isImportant: Bool, isUrgent: Bool, details: String?) throws -> JSONValue
}

struct MCPRouter: Sendable {
    let tools: any MCPToolHandling

    init(tools: any MCPToolHandling) {
        self.tools = tools
    }

    /// Возвращает JSON-RPC ответ или nil для нотификаций, на которые отвечать не нужно.
    func handle(_ request: JSONRPCRequest) async -> JSONValue? {
        if request.method.hasPrefix("notifications/") {
            return nil
        }
        switch request.method {
        case "initialize":
            return JSONRPCResponse.result(id: request.id, [
                "protocolVersion": "2025-03-26",
                "capabilities": ["tools": ["listChanged": false]],
                "serverInfo": ["name": "quarda-mcp", "version": "1.0.0"],
            ])
        case "ping":
            return JSONRPCResponse.result(id: request.id, [:])
        case "tools/list":
            return JSONRPCResponse.result(id: request.id, Self.toolList)
        case "tools/call":
            return await callTool(request)
        default:
            return JSONRPCResponse.error(
                id: request.id,
                code: -32601,
                message: "Method not found: \(request.method)"
            )
        }
    }

    private func callTool(_ request: JSONRPCRequest) async -> JSONValue {
        guard let name = request.params?["name"]?.stringValue else {
            return JSONRPCResponse.error(
                id: request.id,
                code: -32602,
                message: "Invalid params: missing tool name"
            )
        }
        let arguments = request.params?["arguments"]?.objectValue ?? [:]

        do {
            switch name {
            case "add_task":
                guard let title = arguments["title"]?.stringValue,
                      let isImportant = arguments["isImportant"]?.boolValue,
                      let isUrgent = arguments["isUrgent"]?.boolValue
                else {
                    return JSONRPCResponse.error(
                        id: request.id,
                        code: -32602,
                        message: "Invalid params for add_task: title, isImportant and isUrgent are required"
                    )
                }
                let details = arguments["details"]?.stringValue
                let result = try await tools.addTask(
                    title: title,
                    isImportant: isImportant,
                    isUrgent: isUrgent,
                    details: details
                )
                return JSONRPCResponse.result(id: request.id, result)
            case "list_tasks":
                let includeCompleted = arguments["include_completed"]?.boolValue ?? false
                let result = try await tools.listTasks(includeCompleted: includeCompleted)
                return JSONRPCResponse.result(id: request.id, result)
            default:
                return JSONRPCResponse.error(
                    id: request.id,
                    code: -32602,
                    message: "Unknown tool: \(name)"
                )
            }
        } catch {
            return JSONRPCResponse.error(
                id: request.id,
                code: -32603,
                message: "Internal error: \(error.localizedDescription)"
            )
        }
    }

    private static let toolList: JSONValue = [
        "tools": [
            [
                "name": "add_task",
                "description": "Create a task in the Quarda Eisenhower matrix. The quadrant is chosen via isImportant/isUrgent flags. The task appears in the app immediately.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "title": ["type": "string", "description": "Task title"],
                        "isImportant": ["type": "boolean", "description": "Whether the task is important"],
                        "isUrgent": ["type": "boolean", "description": "Whether the task is urgent"],
                        "details": ["type": "string", "description": "Optional task details"],
                    ],
                    "required": [.string("title"), .string("isImportant"), .string("isUrgent")],
                ],
            ],
            [
                "name": "list_tasks",
                "description": "List tasks from the Quarda Eisenhower matrix, grouped by quadrant. Completed tasks are included only when include_completed is true.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "include_completed": ["type": "boolean", "description": "Include completed tasks", "default": false],
                    ],
                ],
            ],
        ],
    ]
}
