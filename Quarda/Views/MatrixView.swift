import AppKit
import SwiftData
import SwiftUI

struct MatrixView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<TaskItem> { $0.isCompleted == false },
        sort: \TaskItem.createdAt
    ) private var activeTasks: [TaskItem]
    @State private var quadrantForNewTask: TaskQuadrant?
    @State private var taskForViewing: TaskItem?
    @State private var taskForEditing: TaskItem?
    @State private var draggedTask: TaskItem?
    @State private var dropPreview: TaskDropPreview?
    @State private var showsCompletedTasks = false
    @State private var completedTaskCount = 0

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ZStack {
            background

            if showsCompletedTasks {
                CompletedTasksView(
                    onBack: { showsCompletedTasks = false },
                    onRestore: restore,
                    onView: { taskForViewing = $0 },
                    onEdit: { taskForEditing = $0 },
                    onDelete: delete
                )
                .padding(26)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            } else {
                matrixContent
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            }

            if let taskForViewing {
                Color.black.opacity(0.28)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture(perform: dismissTaskDetails)
                    .transition(.opacity)
                    .zIndex(1)

                TaskDetailView(
                    task: taskForViewing,
                    onDismiss: dismissTaskDetails
                )
                .background(
                    .thickMaterial,
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.22), radius: 30, y: 14)
                .accessibilityAddTraits(.isModal)
                .transition(.scale(scale: 0.96).combined(with: .opacity))
                .zIndex(2)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: showsCompletedTasks)
        .animation(.easeInOut(duration: 0.16), value: taskForViewing != nil)
        .frame(minWidth: 820, minHeight: 640)
        .task {
            refreshCompletedTaskCount()
        }
        .sheet(item: $quadrantForNewTask) { quadrant in
            AddTaskView(quadrant: quadrant)
        }
        .sheet(item: $taskForEditing) { task in
            EditTaskView(task: task)
        }
    }

    private var matrixContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            header

            GeometryReader { geometry in
                let quadrantHeight = max(250, (geometry.size.height - 16) / 2)

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(TaskQuadrant.allCases) { quadrant in
                        QuadrantView(
                            quadrant: quadrant,
                            tasks: TaskOrganizer.ordered(activeTasks, in: quadrant),
                            draggedTask: $draggedTask,
                            dropPreview: $dropPreview,
                            onAdd: { quadrantForNewTask = quadrant },
                            onView: { taskForViewing = $0 },
                            onEdit: { taskForEditing = $0 },
                            onDelete: delete,
                            onCompletionChange: completionChanged,
                            onMove: move
                        )
                        .frame(height: quadrantHeight)
                    }
                }
            }
        }
        .padding(26)
    }

    private var header: some View {
        HStack(spacing: 11) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
                .shadow(color: .blue.opacity(0.16), radius: 7, y: 3)

            VStack(alignment: .leading, spacing: 1) {
                Text("Quarda")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text("Матрица Эйзенхауэра · Фокус на главном")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            progressSummary
            historyButton
        }
        .padding(.leading, 64)
        .frame(minHeight: 40)
    }

    private var progressSummary: some View {
        let active = activeTasks.count
        let total = active + completedTaskCount
        let progress = total == 0 ? 0 : Double(completedTaskCount) / Double(total)

        return HStack(spacing: 10) {
            HStack(spacing: 6) {
                Circle()
                    .fill(.cyan)
                    .frame(width: 6, height: 6)
                Text("\(active) активных")
                    .font(.caption.weight(.semibold))
            }

            Divider()
                .frame(height: 17)

            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("\(completedTaskCount)/\(total)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(.cyan)
                .frame(width: 68)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule().stroke(.white.opacity(0.12), lineWidth: 1)
        }
    }

    private var historyButton: some View {
        Button {
            showsCompletedTasks = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                Text("История")
                    .fontWeight(.semibold)

                if completedTaskCount > 0 {
                    Text("\(completedTaskCount)")
                        .font(.caption2.bold().monospacedDigit())
                        .foregroundStyle(.indigo)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.white.opacity(0.9), in: Capsule())
                }
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(.indigo)
        .help("Открыть историю выполненных задач")
        .accessibilityLabel("История выполненных задач")
    }

    private var background: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)

            LinearGradient(
                colors: [
                    Color.indigo.opacity(0.10),
                    Color.cyan.opacity(0.035),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.purple.opacity(0.07))
                .frame(width: 380, height: 380)
                .blur(radius: 90)
                .offset(x: -360, y: -260)

            Circle()
                .fill(Color.blue.opacity(0.07))
                .frame(width: 420, height: 420)
                .blur(radius: 100)
                .offset(x: 410, y: 300)
        }
        .ignoresSafeArea()
    }

    private func delete(_ task: TaskItem) {
        let wasCompleted = task.isCompleted
        withAnimation {
            modelContext.delete(task)
        }
        if wasCompleted {
            completedTaskCount = max(0, completedTaskCount - 1)
        }
        Task { @MainActor in
            try? modelContext.save()
        }
    }

    private func restore(_ task: TaskItem) {
        withAnimation(.easeOut(duration: 0.16)) {
            task.isCompleted = false
            task.completedAt = nil
        }
        completedTaskCount = max(0, completedTaskCount - 1)
        Task { @MainActor in
            try? modelContext.save()
        }
    }

    private func completionChanged(_ isCompleted: Bool) {
        completedTaskCount = max(0, completedTaskCount + (isCompleted ? 1 : -1))
    }

    private func dismissTaskDetails() {
        taskForViewing = nil
    }

    private func refreshCompletedTaskCount() {
        if let count = try? CompletedTasksView.fetchCompletedTaskCount(in: modelContext) {
            completedTaskCount = count
        }
    }

    private func move(
        _ task: TaskItem,
        to quadrant: TaskQuadrant,
        before destinationTask: TaskItem?
    ) {
        withAnimation(.easeOut(duration: 0.14)) {
            TaskOrganizer.move(
                task,
                to: quadrant,
                before: destinationTask,
                in: activeTasks
            )
        }
        Task { @MainActor in
            try? modelContext.save()
        }
    }
}

#Preview {
    MatrixView()
        .modelContainer(for: TaskItem.self, inMemory: true)
}
