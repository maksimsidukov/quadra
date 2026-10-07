import SwiftData
import SwiftUI

struct CompletedTasksView: View {
    @Environment(\.modelContext) private var modelContext
    let onBack: () -> Void
    let onRestore: (TaskItem) -> Void
    let onView: (TaskItem) -> Void
    let onEdit: (TaskItem) -> Void
    let onDelete: (TaskItem) -> Void
    @State private var tasks: [TaskItem] = []
    @State private var totalTaskCount = 0
    @State private var didLoad = false
    @State private var isLoading = false
    @State private var canLoadMore = true
    @State private var loadError: String?

    private let pageSize = 50

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header

            if !didLoad || (tasks.isEmpty && isLoading) {
                ProgressView("Загружаем историю…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if tasks.isEmpty, loadError != nil {
                loadFailure
            } else if tasks.isEmpty {
                ContentUnavailableView {
                    Label("Пока ничего не выполнено", systemImage: "checkmark.circle")
                } description: {
                    Text("Завершённые задачи появятся здесь")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        ForEach(Self.groupedByCompletionDay(tasks)) { group in
                            VStack(alignment: .leading, spacing: 10) {
                                dayHeader(for: group.day)

                                ForEach(group.tasks) { task in
                                    CompletedTaskRow(
                                        task: task,
                                        onRestore: { restore(task) },
                                        onView: { onView(task) },
                                        onEdit: { onEdit(task) },
                                        onDelete: { delete(task) }
                                    )
                                }
                            }
                        }

                        loadMoreFooter
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .task {
            loadInitialPage()
        }
    }

    private var header: some View {
        HStack(spacing: 13) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.callout.bold())
                    .frame(width: 32, height: 32)
                    .background(.regularMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .help("Вернуться к матрице")

            VStack(alignment: .leading, spacing: 2) {
                Text("Выполненные")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("Архив завершённых задач")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("\(totalTaskCount)")
                .font(.caption.bold())
                .foregroundStyle(.green)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(.green.opacity(0.12), in: Capsule())

            Spacer()
        }
        .padding(.leading, 64)
        .frame(minHeight: 40)
    }

    @ViewBuilder
    private var loadMoreFooter: some View {
        if isLoading {
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        } else if let loadError {
            VStack(spacing: 8) {
                Text(loadError)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Повторить", action: loadNextPage)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        } else if canLoadMore {
            Color.clear
                .frame(height: 1)
                .onAppear(perform: loadNextPage)
        }
    }

    private var loadFailure: some View {
        VStack(spacing: 14) {
            ContentUnavailableView {
                Label("Не удалось загрузить историю", systemImage: "exclamationmark.triangle")
            } description: {
                Text(loadError ?? "Попробуйте ещё раз")
            }

            Button("Повторить", action: loadNextPage)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    static func fetchCompletedTaskCount(in modelContext: ModelContext) throws -> Int {
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.isCompleted }
        )
        return try modelContext.fetchCount(descriptor)
    }

    static func fetchCompletedTasks(
        in modelContext: ModelContext,
        offset: Int,
        limit: Int
    ) throws -> [TaskItem] {
        var descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.isCompleted },
            sortBy: [
                SortDescriptor(\TaskItem.completedAt, order: .reverse),
                SortDescriptor(\TaskItem.createdAt, order: .reverse)
            ]
        )
        descriptor.fetchOffset = offset
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor)
    }

    private func loadInitialPage() {
        guard !didLoad else { return }
        didLoad = true
        loadNextPage(refreshCount: true)
    }

    private func loadNextPage() {
        loadNextPage(refreshCount: tasks.isEmpty)
    }

    private func loadNextPage(refreshCount: Bool) {
        guard !isLoading, canLoadMore else { return }

        isLoading = true
        loadError = nil

        Task { @MainActor in
            await Task.yield()

            do {
                if refreshCount {
                    totalTaskCount = try Self.fetchCompletedTaskCount(in: modelContext)
                }

                let page = try Self.fetchCompletedTasks(
                    in: modelContext,
                    offset: tasks.count,
                    limit: pageSize
                )
                let loadedTasks = Set(tasks.map(\.persistentModelID))
                tasks.append(contentsOf: page.filter { !loadedTasks.contains($0.persistentModelID) })
                canLoadMore = !page.isEmpty && tasks.count < totalTaskCount
            } catch {
                loadError = "Не удалось прочитать данные"
            }

            isLoading = false
        }
    }

    private func restore(_ task: TaskItem) {
        onRestore(task)
        removeLoaded(task)
    }

    private func delete(_ task: TaskItem) {
        onDelete(task)
        removeLoaded(task)
    }

    private func removeLoaded(_ task: TaskItem) {
        tasks.removeAll { $0 === task }
        totalTaskCount = max(0, totalTaskCount - 1)
        canLoadMore = tasks.count < totalTaskCount
    }

    static func groupedByCompletionDay(
        _ tasks: [TaskItem],
        calendar: Calendar = .autoupdatingCurrent
    ) -> [CompletedTaskDay] {
        Dictionary(grouping: tasks) { task in
            calendar.startOfDay(for: task.completedAt ?? task.createdAt)
        }
        .map { day, tasks in
            CompletedTaskDay(
                day: day,
                tasks: tasks.sorted {
                    ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt)
                }
            )
        }
        .sorted { $0.day > $1.day }
    }

    private func dayHeader(for day: Date) -> some View {
        HStack(spacing: 8) {
            Text(dayTitle(for: day))
                .font(.headline)

            Rectangle()
                .fill(.quaternary)
                .frame(height: 1)
        }
    }

    private func dayTitle(for day: Date) -> String {
        let calendar = Calendar.autoupdatingCurrent

        if calendar.isDateInToday(day) {
            return "Сегодня"
        }
        if calendar.isDateInYesterday(day) {
            return "Вчера"
        }
        return day.formatted(.dateTime.day().month(.wide).year())
    }
}

struct CompletedTaskDay: Identifiable {
    let day: Date
    let tasks: [TaskItem]

    var id: Date { day }
}

private struct CompletedTaskRow: View {
    let task: TaskItem
    let onRestore: () -> Void
    let onView: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: "checkmark")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(.green, in: Circle())

            VStack(alignment: .leading, spacing: 6) {
                Text(task.title)
                    .font(.body.weight(.semibold))

                if let details = task.details, !details.isEmpty {
                    Text(details)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                HStack(spacing: 9) {
                    Label(task.quadrant.title, systemImage: task.quadrant.systemImage)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(task.quadrant.tint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(task.quadrant.tint.opacity(0.10), in: Capsule())

                    if let completedAt = task.completedAt {
                        Text(
                            completedAt,
                            format: .dateTime
                                .day()
                                .month(.wide)
                                .year()
                                .hour()
                                .minute()
                        )
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onView)

            Spacer(minLength: 12)

            Button(action: onRestore) {
                Label("Вернуть", systemImage: "arrow.uturn.backward")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Вернуть задачу в матрицу")

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Редактировать задачу")

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .foregroundStyle(isHovering ? Color.red.opacity(0.8) : Color.secondary)
            .help("Удалить задачу")
        }
        .padding(15)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 15))
        .overlay {
            RoundedRectangle(cornerRadius: 15)
                .stroke(isHovering ? Color.green.opacity(0.18) : Color.primary.opacity(0.06))
        }
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Вернуть в матрицу", systemImage: "arrow.uturn.backward", action: onRestore)
            Button("Редактировать", systemImage: "pencil", action: onEdit)
            Button("Удалить", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }
}
