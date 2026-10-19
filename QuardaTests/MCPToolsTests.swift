import SwiftData
import XCTest
@testable import Quarda

@MainActor
final class MCPToolsTests: XCTestCase {
    private var container: ModelContainer!
    private var handler: TaskToolHandler!

    override func setUp() {
        super.setUp()
        container = try! ModelContainer(
            for: Schema([TaskItem.self]),
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        handler = TaskToolHandler(container: container)
    }

    override func tearDown() {
        handler = nil
        container = nil
        super.tearDown()
    }

    private func fetchAll() throws -> [TaskItem] {
        try ModelContext(container).fetch(FetchDescriptor<TaskItem>())
    }

    /// Достаёт JSON-полезную нагрузку из MCP tool result (content[0].text).
    private func payload(of result: JSONValue) throws -> [String: Any] {
        let object = try XCTUnwrap(result.objectValue)
        let content = try XCTUnwrap(object["content"]?.arrayValue)
        let text = try XCTUnwrap(content.first?.objectValue?["text"]?.stringValue)
        let data = try XCTUnwrap(text.data(using: .utf8))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func isError(_ result: JSONValue) -> Bool {
        result.objectValue?["isError"]?.boolValue ?? false
    }

    func testAddTaskCreatesTaskInCorrectQuadrantAtEnd() throws {
        let first = try handler.addTask(title: "A", isImportant: true, isUrgent: false, details: "d")
        XCTAssertFalse(isError(first))

        let tasks = try fetchAll()
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks.first?.quadrant, .schedule)
        XCTAssertEqual(tasks.first?.details, "d")
        XCTAssertEqual(tasks.first?.isCompleted, false)

        _ = try handler.addTask(title: "B", isImportant: true, isUrgent: false, details: nil)
        let ordered = TaskOrganizer.ordered(try fetchAll(), in: .schedule)
        XCTAssertEqual(ordered.map(\.title), ["A", "B"])
        XCTAssertEqual(ordered.last?.sortOrder, (ordered.first?.sortOrder ?? 0) + 1)
    }

    func testAddTaskRejectsBlankTitle() throws {
        let result = try handler.addTask(title: "  ", isImportant: true, isUrgent: true, details: nil)
        XCTAssertTrue(isError(result))
        XCTAssertEqual(try fetchAll().count, 0)
    }

    func testListTasksExcludesCompletedByDefault() throws {
        _ = try handler.addTask(title: "Active", isImportant: true, isUrgent: true, details: nil)
        _ = try handler.addTask(title: "Done", isImportant: true, isUrgent: true, details: nil)
        let context = ModelContext(container)
        let done = try XCTUnwrap(
            try context.fetch(FetchDescriptor<TaskItem>()).first { $0.title == "Done" }
        )
        done.isCompleted = true
        done.completedAt = Date(timeIntervalSince1970: 1_700_000_000)
        try context.save()

        let activeOnly = try payload(of: handler.listTasks(includeCompleted: false))
        let activeTitles = (activeOnly["tasks"] as? [[String: Any]])?.compactMap { $0["title"] as? String }
        XCTAssertEqual(activeTitles, ["Active"])

        let everything = try payload(of: handler.listTasks(includeCompleted: true))
        let allTitles = (everything["tasks"] as? [[String: Any]])?.compactMap { $0["title"] as? String }
        XCTAssertEqual(allTitles, ["Active", "Done"])
    }

    func testRouterCallAddTaskEndToEnd() async throws {
        let router = MCPRouter(tools: handler)
        let response = await router.handle(JSONRPCRequest(
            jsonrpc: "2.0",
            id: 1,
            method: "tools/call",
            params: [
                "name": "add_task",
                "arguments": ["title": "Via router", "isImportant": false, "isUrgent": true],
            ]
        ))

        XCTAssertNotNil(response?.objectValue?["result"])
        XCTAssertNil(response?.objectValue?["error"])

        let tasks = try fetchAll()
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks.first?.title, "Via router")
        XCTAssertEqual(tasks.first?.quadrant, .delegate)
    }
}
