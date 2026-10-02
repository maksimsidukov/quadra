import AppKit
import SwiftData
import SwiftUI

struct MatrixView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.createdAt) private var tasks: [TaskItem]
    @State private var quadrantForNewTask: TaskQuadrant?
    @State private var taskForViewing: TaskItem?
    @State private var taskForEditing: TaskItem?
    @State private var draggedTask: TaskItem?
    @State private var dropPreview: TaskDropPreview?
    @State private var showsCompletedTasks = false

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ZStack {
            background

            if showsCompletedTasks {
                CompletedTasksView(
                    tasks: completedTasks,
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
        }
        .animation(.easeInOut(duration: 0.18), value: showsCompletedTasks)
        .frame(minWidth: 820, minHeight: 640)
        .sheet(item: $quadrantForNewTask) { quadrant in
            AddTaskView(quadrant: quadrant)
        }
        .sheet(item: $taskForEditing) { task in
            EditTaskView(task: task)
        }
        .sheet(item: $taskForViewing) { task in
            TaskDetailView(task: task)
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
                            onMove: move
                        )
                        .frame(height: quadrantHeight)
                    }
                }
            }
        }
        .padding(26)
    }

    private var activeTasks: [TaskItem] {
        tasks.filter { !$0.isCompleted }
    }

    private var completedTasks: [TaskItem] {
        tasks
            .filter(\.isCompleted)
            .sorted { ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt) }
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
        let completed = tasks.filter(\.isCompleted).count
        let active = tasks.count - completed
        let progress = tasks.isEmpty ? 0 : Double(completed) / Double(tasks.count)

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
            Text("\(completed)/\(tasks.count)")
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

                if !completedTasks.isEmpty {
                    Text("\(completedTasks.count)")
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
        withAnimation {
            modelContext.delete(task)
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
        Task { @MainActor in
            try? modelContext.save()
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
