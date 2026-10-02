import Foundation
import SwiftData

@Model
final class TaskItem {
    var title: String
    var isImportant: Bool
    var isUrgent: Bool
    var isCompleted: Bool
    var createdAt: Date
    var sortOrder: Int = 0
    var details: String?
    var completedAt: Date?

    init(
        title: String,
        quadrant: TaskQuadrant,
        details: String? = nil,
        createdAt: Date = .now,
        sortOrder: Int = 0
    ) {
        self.title = title
        self.isImportant = quadrant.isImportant
        self.isUrgent = quadrant.isUrgent
        self.isCompleted = false
        self.createdAt = createdAt
        self.sortOrder = sortOrder
        self.details = details
        self.completedAt = nil
    }

    var quadrant: TaskQuadrant {
        TaskQuadrant(isImportant: isImportant, isUrgent: isUrgent)
    }
}
