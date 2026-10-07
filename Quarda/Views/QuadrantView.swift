import UniformTypeIdentifiers
import SwiftUI

struct TaskDropPreview {
    let quadrant: TaskQuadrant
    let beforeTask: TaskItem?

    func isBefore(_ task: TaskItem, in quadrant: TaskQuadrant) -> Bool {
        self.quadrant == quadrant && beforeTask === task
    }

    func isAtEnd(of quadrant: TaskQuadrant) -> Bool {
        self.quadrant == quadrant && beforeTask == nil
    }
}

struct QuadrantView: View {
    let quadrant: TaskQuadrant
    let tasks: [TaskItem]
    @Binding var draggedTask: TaskItem?
    @Binding var dropPreview: TaskDropPreview?
    let onAdd: () -> Void
    let onView: (TaskItem) -> Void
    let onEdit: (TaskItem) -> Void
    let onDelete: (TaskItem) -> Void
    let onCompletionChange: (Bool) -> Void
    let onMove: (TaskItem, TaskQuadrant, TaskItem?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            header

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [quadrant.tint.opacity(0.5), quadrant.tint.opacity(0.04)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)

            if tasks.isEmpty {
                Button(action: onAdd) {
                    VStack(spacing: 9) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(quadrant.tint.opacity(0.8))
                        Text("Добавить первую задачу")
                            .font(.callout.weight(.medium))
                        Text("Перетащить сюда тоже можно")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    RoundedRectangle(cornerRadius: 13)
                        .strokeBorder(
                            quadrant.tint.opacity(0.16),
                            style: StrokeStyle(lineWidth: 1, dash: [5, 5])
                        )
                }
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 8) {
                        ForEach(tasks) { task in
                            TaskRowView(
                                task: task,
                                onView: { onView(task) },
                                onEdit: { onEdit(task) },
                                onDelete: { onDelete(task) },
                                onCompletionChange: onCompletionChange,
                                onDrag: {
                                    draggedTask = task
                                    return NSItemProvider(object: task.title as NSString)
                                }
                            )
                                .contentShape(Rectangle())
                                .opacity(draggedTask === task ? 0.45 : 1)
                                .onDrop(
                                    of: [UTType.text],
                                    delegate: TaskDropDelegate(
                                        destinationTask: task,
                                        destinationQuadrant: quadrant,
                                        tasks: tasks,
                                        draggedTask: $draggedTask,
                                        dropPreview: $dropPreview,
                                        onMove: onMove
                                    )
                                )
                                .overlay(alignment: .top) {
                                    if dropPreview?.isBefore(task, in: quadrant) == true {
                                        DropInsertionIndicator(tint: quadrant.tint)
                                            .offset(y: -5)
                                    }
                                }
                                .overlay(alignment: .bottom) {
                                    if isLastTask(task),
                                       dropPreview?.isAtEnd(of: quadrant) == true {
                                        DropInsertionIndicator(tint: quadrant.tint)
                                            .offset(y: 5)
                                    }
                                }
                        }
                    }
                    .padding(.vertical, 1)
                    .padding(.trailing, 4)
                }
                .frame(maxHeight: .infinity)
                .clipped()
            }
        }
        .padding(17)
        .frame(maxWidth: .infinity, minHeight: 250, maxHeight: .infinity, alignment: .top)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [quadrant.tint.opacity(0.10), .clear],
                                startPoint: .topLeading,
                                endPoint: .center
                            )
                        )
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    quadrant.tint.opacity(isDropTarget ? 0.55 : 0.22),
                    lineWidth: isDropTarget ? 1.5 : 1
                )
        }
        .shadow(color: quadrant.tint.opacity(0.06), radius: 16, y: 8)
        .onDrop(
            of: [UTType.text],
            delegate: TaskDropDelegate(
                destinationTask: nil,
                destinationQuadrant: quadrant,
                tasks: tasks,
                draggedTask: $draggedTask,
                dropPreview: $dropPreview,
                onMove: onMove
            )
        )
    }

    private var isDropTarget: Bool {
        dropPreview?.quadrant == quadrant
    }

    private func isLastTask(_ task: TaskItem) -> Bool {
        tasks.last.map { $0 === task } ?? false
    }

    private var header: some View {
        HStack(spacing: 11) {
            Image(systemName: quadrant.systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 35, height: 35)
                .background(
                    LinearGradient(
                        colors: [quadrant.tint, quadrant.tint.opacity(0.68)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .shadow(color: quadrant.tint.opacity(0.28), radius: 6, y: 3)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 7) {
                    Text(quadrant.title)
                        .font(.headline)
                    Text("\(tasks.count)")
                        .font(.caption2.bold())
                        .foregroundStyle(quadrant.tint)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(quadrant.tint.opacity(0.12), in: Capsule())
                }
                Text(quadrant.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button(action: onAdd) {
                Label("Добавить", systemImage: "plus")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(quadrant.tint.opacity(0.11), in: Capsule())
            }
            .buttonStyle(.plain)
            .foregroundStyle(quadrant.tint)
            .help("Добавить задачу")
            .accessibilityLabel("Добавить задачу в «\(quadrant.title)»")
        }
    }
}

private struct DropInsertionIndicator: View {
    let tint: Color

    var body: some View {
        Capsule()
            .fill(tint)
            .frame(height: 3)
            .padding(.horizontal, 9)
            .shadow(color: tint.opacity(0.5), radius: 4)
            .transition(.opacity.combined(with: .scale(scale: 0.85)))
    }
}

private struct TaskDropDelegate: DropDelegate {
    let destinationTask: TaskItem?
    let destinationQuadrant: TaskQuadrant
    let tasks: [TaskItem]
    @Binding var draggedTask: TaskItem?
    @Binding var dropPreview: TaskDropPreview?
    let onMove: (TaskItem, TaskQuadrant, TaskItem?) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        draggedTask != nil
    }

    func dropEntered(info: DropInfo) {
        guard let taskBeingDragged = draggedTask else { return }
        let insertionPoint = insertionPoint(for: taskBeingDragged)

        withAnimation(.easeOut(duration: 0.12)) {
            if insertionPoint === taskBeingDragged {
                dropPreview = nil
            } else {
                dropPreview = TaskDropPreview(
                    quadrant: destinationQuadrant,
                    beforeTask: insertionPoint
                )
            }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let taskBeingDragged = draggedTask else { return false }
        let destinationTask = insertionPoint(for: taskBeingDragged)

        draggedTask = nil
        dropPreview = nil

        onMove(
            taskBeingDragged,
            destinationQuadrant,
            destinationTask
        )
        return true
    }

    private func insertionPoint(for draggedTask: TaskItem) -> TaskItem? {
        guard let destinationTask,
              draggedTask.quadrant == destinationQuadrant,
              let sourceIndex = tasks.firstIndex(where: { $0 === draggedTask }),
              let destinationIndex = tasks.firstIndex(where: { $0 === destinationTask }),
              sourceIndex < destinationIndex else {
            return destinationTask
        }

        let followingIndex = tasks.index(after: destinationIndex)
        return followingIndex < tasks.endIndex ? tasks[followingIndex] : nil
    }
}
