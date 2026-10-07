import Foundation
import SwiftData
import SwiftUI

struct TaskRowView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var task: TaskItem
    let onView: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onCompletionChange: (Bool) -> Void
    let onDrag: () -> NSItemProvider
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 9) {
            Toggle("Выполнено", isOn: completionBinding)
                .toggleStyle(.checkbox)
                .labelsHidden()
                .help(task.isCompleted ? "Вернуть в работу" : "Отметить выполненной")

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.callout.weight(.medium))
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)

                if let details = task.details, !details.isEmpty {
                    Text(details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onView)
            .onDrag(onDrag)
            .help("Нажмите для просмотра или перетащите задачу")

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .opacity(isHovering ? 1 : 0.35)
            .help("Редактировать задачу")
            .accessibilityLabel("Редактировать задачу «\(task.title)»")

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .foregroundStyle(isHovering ? Color.red.opacity(0.8) : Color.secondary)
            .opacity(isHovering ? 1 : 0.25)
            .help("Удалить задачу")
            .accessibilityLabel("Удалить задачу «\(task.title)»")
        }
        .padding(.horizontal, 11)
        .background {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(isHovering ? task.quadrant.tint.opacity(0.08) : Color.primary.opacity(0.035))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(
                    isHovering ? task.quadrant.tint.opacity(0.18) : Color.primary.opacity(0.05),
                    lineWidth: 1
                )
        }
        .opacity(task.isCompleted ? 0.72 : 1)
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Редактировать", systemImage: "pencil", action: onEdit)
            Button("Удалить", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }

    private var completionBinding: Binding<Bool> {
        Binding(
            get: { task.isCompleted },
            set: { isCompleted in
                withAnimation(.easeOut(duration: 0.12)) {
                    task.isCompleted = isCompleted
                    task.completedAt = isCompleted ? .now : nil
                }
                onCompletionChange(isCompleted)
                Task { @MainActor in
                    try? modelContext.save()
                }
            }
        )
    }
}
