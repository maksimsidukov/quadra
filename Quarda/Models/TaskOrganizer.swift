import Foundation

enum TaskOrganizer {
    static func ordered(_ tasks: [TaskItem], in quadrant: TaskQuadrant) -> [TaskItem] {
        tasks
            .filter { $0.quadrant == quadrant }
            .sorted {
                if $0.sortOrder == $1.sortOrder {
                    return $0.createdAt < $1.createdAt
                }
                return $0.sortOrder < $1.sortOrder
            }
    }

    static func nextSortOrder(for quadrant: TaskQuadrant, in tasks: [TaskItem]) -> Int {
        (ordered(tasks, in: quadrant).map(\.sortOrder).max() ?? -1) + 1
    }

    static func move(
        _ task: TaskItem,
        to destinationQuadrant: TaskQuadrant,
        before destinationTask: TaskItem?,
        in allTasks: [TaskItem]
    ) {
        guard destinationTask !== task else { return }

        let sourceQuadrant = task.quadrant
        var destinationTasks = ordered(allTasks, in: destinationQuadrant)
            .filter { $0 !== task }

        let insertionIndex: Int
        if let destinationTask,
           let targetIndex = destinationTasks.firstIndex(where: { $0 === destinationTask }) {
            insertionIndex = targetIndex
        } else {
            insertionIndex = destinationTasks.endIndex
        }

        task.isImportant = destinationQuadrant.isImportant
        task.isUrgent = destinationQuadrant.isUrgent
        destinationTasks.insert(task, at: insertionIndex)
        renumber(destinationTasks)

        if sourceQuadrant != destinationQuadrant {
            renumber(ordered(allTasks, in: sourceQuadrant))
        }
    }

    private static func renumber(_ tasks: [TaskItem]) {
        for (index, task) in tasks.enumerated() {
            task.sortOrder = index
        }
    }
}
