import SwiftUI

struct CompletedTasksView: View {
    let tasks: [TaskItem]
    let onBack: () -> Void
    let onRestore: (TaskItem) -> Void
    let onView: (TaskItem) -> Void
    let onEdit: (TaskItem) -> Void
    let onDelete: (TaskItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header

            if tasks.isEmpty {
                ContentUnavailableView {
                    Label("Пока ничего не выполнено", systemImage: "checkmark.circle")
                } description: {
                    Text("Завершённые задачи появятся здесь")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 10) {
                        ForEach(tasks) { task in
                            CompletedTaskRow(
                                task: task,
                                onRestore: { onRestore(task) },
                                onView: { onView(task) },
                                onEdit: { onEdit(task) },
                                onDelete: { onDelete(task) }
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
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

            Text("\(tasks.count)")
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
