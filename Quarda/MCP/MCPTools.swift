import Foundation
import SwiftData

@MainActor
final class TaskToolHandler: MCPToolHandling {
    private let context: ModelContext

    init(container: ModelContainer) {
        self.context = ModelContext(container)
    }

    func addTask(title: String, isImportant: Bool, isUrgent: Bool, details: String?) throws -> JSONValue {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return Self.toolResult(["error": "title must not be empty"], isError: true)
        }

        let quadrant = TaskQuadrant(isImportant: isImportant, isUrgent: isUrgent)
        let allTasks = try context.fetch(FetchDescriptor<TaskItem>())
        let task = TaskItem(
            title: trimmed,
            quadrant: quadrant,
            details: details?.isEmpty == true ? nil : details,
            sortOrder: TaskOrganizer.nextSortOrder(for: quadrant, in: allTasks)
        )
        context.insert(task)
        try context.save()

        return Self.toolResult([
            "title": .string(task.title),
            "quadrant": .string(String(describing: task.quadrant)),
            "sortOrder": .number(Double(task.sortOrder)),
        ])
    }

    func listTasks(includeCompleted: Bool) throws -> JSONValue {
        let allTasks = try context.fetch(FetchDescriptor<TaskItem>())
        let tasks = includeCompleted ? allTasks : allTasks.filter { !$0.isCompleted }
        let formatter = ISO8601DateFormatter()

        var items: [JSONValue] = []
        for quadrant in TaskQuadrant.allCases {
            for task in TaskOrganizer.ordered(tasks, in: quadrant) {
                items.append(.object([
                    "title": .string(task.title),
                    "quadrant": .string(String(describing: quadrant)),
                    "isImportant": .bool(task.isImportant),
                    "isUrgent": .bool(task.isUrgent),
                    "details": task.details.map(JSONValue.string) ?? .null,
                    "isCompleted": .bool(task.isCompleted),
                    "createdAt": .string(formatter.string(from: task.createdAt)),
                    "completedAt": task.completedAt.map { .string(formatter.string(from: $0)) } ?? .null,
                ]))
            }
        }
        return Self.toolResult(["tasks": .array(items)])
    }

    /// Обертка результата инструмента в формат MCP tool result.
    static func toolResult(_ payload: JSONValue, isError: Bool = false) -> JSONValue {
        let data = (try? JSONEncoder().encode(payload)) ?? Data()
        let text = String(data: data, encoding: .utf8) ?? "{}"
        return .object([
            "content": [["type": "text", "text": .string(text)]],
            "isError": isError,
        ])
    }
}
