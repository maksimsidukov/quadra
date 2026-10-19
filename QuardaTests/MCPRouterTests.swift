import XCTest
@testable import Quarda

@MainActor
final class StubTools: MCPToolHandling {
    var addTaskCalls: [(title: String, isImportant: Bool, isUrgent: Bool, details: String?)] = []
    var listTasksCalls: [Bool] = []

    func listTasks(includeCompleted: Bool) throws -> JSONValue {
        listTasksCalls.append(includeCompleted)
        return ["ok": true]
    }

    func addTask(title: String, isImportant: Bool, isUrgent: Bool, details: String?) throws -> JSONValue {
        addTaskCalls.append((title, isImportant, isUrgent, details))
        return ["ok": true]
    }
}

@MainActor
final class MCPRouterTests: XCTestCase {
    private func makeRequest(
        _ method: String,
        id: JSONValue? = 1,
        params: [String: JSONValue]? = nil
    ) -> JSONRPCRequest {
        JSONRPCRequest(jsonrpc: "2.0", id: id, method: method, params: params)
    }

    func testInitializeReturnsServerInfo() async {
        let router = MCPRouter(tools: StubTools())
        let response = await router.handle(makeRequest("initialize"))
        let result = response?.objectValue?["result"]?.objectValue
        XCTAssertEqual(result?["protocolVersion"], "2025-03-26")
        XCTAssertEqual(result?["serverInfo"]?.objectValue?["name"], "quarda-mcp")
    }

    func testInitializedNotificationReturnsNil() async {
        let router = MCPRouter(tools: StubTools())
        let response = await router.handle(makeRequest("notifications/initialized", id: nil))
        XCTAssertNil(response)
    }

    func testUnknownMethodReturnsError() async {
        let router = MCPRouter(tools: StubTools())
        let response = await router.handle(makeRequest("bogus/method"))
        XCTAssertEqual(response?.objectValue?["error"]?.objectValue?["code"], .number(-32601))
    }

    func testToolsListContainsBothTools() async {
        let router = MCPRouter(tools: StubTools())
        let response = await router.handle(makeRequest("tools/list"))
        let tools = response?.objectValue?["result"]?.objectValue?["tools"]?.arrayValue
        let names = tools?.compactMap { $0.objectValue?["name"]?.stringValue }
        XCTAssertEqual(names, ["add_task", "list_tasks"])

        let addTask = tools?.first?.objectValue
        let required = addTask?["inputSchema"]?.objectValue?["required"]?.arrayValue
        XCTAssertEqual(required, ["title", "isImportant", "isUrgent"])
    }

    func testUnknownToolReturnsInvalidParams() async {
        let router = MCPRouter(tools: StubTools())
        let response = await router.handle(makeRequest("tools/call", params: ["name": "nope"]))
        XCTAssertEqual(response?.objectValue?["error"]?.objectValue?["code"], .number(-32602))
    }

    func testToolCallDispatchesArguments() async {
        let stub = StubTools()
        let router = MCPRouter(tools: stub)
        let response = await router.handle(makeRequest(
            "tools/call",
            params: [
                "name": "add_task",
                "arguments": [
                    "title": "T",
                    "isImportant": true,
                    "isUrgent": false,
                    "details": "d",
                ],
            ]
        ))

        XCTAssertNotNil(response?.objectValue?["result"])
        XCTAssertNil(response?.objectValue?["error"])
        XCTAssertEqual(stub.addTaskCalls.count, 1)
        XCTAssertEqual(stub.addTaskCalls.first?.title, "T")
        XCTAssertEqual(stub.addTaskCalls.first?.isImportant, true)
        XCTAssertEqual(stub.addTaskCalls.first?.isUrgent, false)
        XCTAssertEqual(stub.addTaskCalls.first?.details, "d")
    }
}
