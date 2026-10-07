import SwiftData
import XCTest
@testable import Quarda

final class TaskQuadrantTests: XCTestCase {
    func testFlagsMapToExpectedQuadrants() {
        XCTAssertEqual(TaskQuadrant(isImportant: true, isUrgent: true), .doNow)
        XCTAssertEqual(TaskQuadrant(isImportant: true, isUrgent: false), .schedule)
        XCTAssertEqual(TaskQuadrant(isImportant: false, isUrgent: true), .delegate)
        XCTAssertEqual(TaskQuadrant(isImportant: false, isUrgent: false), .eliminate)
    }

    func testEveryQuadrantRoundTripsThroughFlags() {
        for quadrant in TaskQuadrant.allCases {
            XCTAssertEqual(
                TaskQuadrant(isImportant: quadrant.isImportant, isUrgent: quadrant.isUrgent),
                quadrant
            )
        }
    }

    @MainActor
    func testTasksRemainAfterContainerIsReopened() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let storeURL = directory.appendingPathComponent("tasks.store")

        do {
            let container = try AppDataStore.makeModelContainer(at: storeURL)
            let context = ModelContext(container)
            let task = TaskItem(
                title: "Сохранённая задача",
                quadrant: .schedule,
                details: "Подробности тоже должны сохраниться"
            )
            task.isCompleted = true
            task.completedAt = Date(timeIntervalSince1970: 1_700_000_000)
            context.insert(task)
            try context.save()
        }

        let reopenedContainer = try AppDataStore.makeModelContainer(at: storeURL)
        let reopenedContext = ModelContext(reopenedContainer)
        let tasks = try reopenedContext.fetch(FetchDescriptor<TaskItem>())

        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks.first?.title, "Сохранённая задача")
        XCTAssertEqual(tasks.first?.details, "Подробности тоже должны сохраниться")
        XCTAssertEqual(tasks.first?.quadrant, .schedule)
        XCTAssertEqual(tasks.first?.isCompleted, true)
        XCTAssertEqual(
            tasks.first?.completedAt,
            Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    func testTasksCanBeReorderedAndMovedBetweenQuadrants() {
        let first = TaskItem(title: "Первая", quadrant: .doNow, sortOrder: 0)
        let second = TaskItem(title: "Вторая", quadrant: .doNow, sortOrder: 1)
        let scheduled = TaskItem(title: "План", quadrant: .schedule, sortOrder: 0)
        let tasks = [first, second, scheduled]

        TaskOrganizer.move(second, to: .doNow, before: first, in: tasks)

        let reordered = TaskOrganizer.ordered(tasks, in: .doNow)
        XCTAssertTrue(reordered[0] === second)
        XCTAssertTrue(reordered[1] === first)

        TaskOrganizer.move(second, to: .schedule, before: scheduled, in: tasks)

        let source = TaskOrganizer.ordered(tasks, in: .doNow)
        let destination = TaskOrganizer.ordered(tasks, in: .schedule)
        XCTAssertEqual(source.count, 1)
        XCTAssertTrue(source[0] === first)
        XCTAssertTrue(destination[0] === second)
        XCTAssertTrue(destination[1] === scheduled)
        XCTAssertEqual(second.quadrant, .schedule)
    }

    @MainActor
    func testCompletedTasksAreGroupedByDayAndSortedNewestFirst() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let older = TaskItem(title: "Позавчера", quadrant: .doNow)
        older.completedAt = Date(timeIntervalSince1970: 1_700_000_000)

        let newer = TaskItem(title: "Сегодня позже", quadrant: .schedule)
        newer.completedAt = Date(timeIntervalSince1970: 1_700_176_400)

        let earlierSameDay = TaskItem(title: "Сегодня раньше", quadrant: .delegate)
        earlierSameDay.completedAt = Date(timeIntervalSince1970: 1_700_172_800)

        let groups = CompletedTasksView.groupedByCompletionDay(
            [older, earlierSameDay, newer],
            calendar: calendar
        )

        XCTAssertEqual(groups.count, 2)
        XCTAssertTrue(groups[0].tasks[0] === newer)
        XCTAssertTrue(groups[0].tasks[1] === earlierSameDay)
        XCTAssertTrue(groups[1].tasks[0] === older)
    }

    @MainActor
    func testCompletedTasksAreFetchedInPagesNewestFirst() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: TaskItem.self,
            configurations: configuration
        )
        let context = ModelContext(container)

        for index in 0..<75 {
            let task = TaskItem(
                title: "Выполненная \(index)",
                quadrant: .doNow,
                createdAt: Date(timeIntervalSince1970: Double(index))
            )
            task.isCompleted = true
            task.completedAt = Date(timeIntervalSince1970: Double(index))
            context.insert(task)
        }

        context.insert(TaskItem(title: "Активная", quadrant: .schedule))
        try context.save()

        let total = try CompletedTasksView.fetchCompletedTaskCount(in: context)
        let firstPage = try CompletedTasksView.fetchCompletedTasks(
            in: context,
            offset: 0,
            limit: 50
        )
        let secondPage = try CompletedTasksView.fetchCompletedTasks(
            in: context,
            offset: firstPage.count,
            limit: 50
        )

        XCTAssertEqual(total, 75)
        XCTAssertEqual(firstPage.count, 50)
        XCTAssertEqual(secondPage.count, 25)
        XCTAssertEqual(firstPage.first?.title, "Выполненная 74")
        XCTAssertEqual(firstPage.last?.title, "Выполненная 25")
        XCTAssertEqual(secondPage.first?.title, "Выполненная 24")
        XCTAssertEqual(secondPage.last?.title, "Выполненная 0")

        let identifiers = Set((firstPage + secondPage).map(\.persistentModelID))
        XCTAssertEqual(identifiers.count, 75)
    }
}
