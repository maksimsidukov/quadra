import SwiftData
import SwiftUI

struct EditTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let task: TaskItem
    @State private var title: String
    @State private var details: String

    init(task: TaskItem) {
        self.task = task
        _title = State(initialValue: task.title)
        _details = State(initialValue: task.details ?? "")
    }

    private var normalizedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedDetails: String? {
        let value = details.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [task.quadrant.tint.opacity(0.13), Color.clear],
                startPoint: .topLeading,
                endPoint: .center
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 13) {
                    Image(systemName: task.quadrant.systemImage)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            LinearGradient(
                                colors: [task.quadrant.tint, task.quadrant.tint.opacity(0.65)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                        )
                        .shadow(color: task.quadrant.tint.opacity(0.25), radius: 8, y: 4)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Редактировать задачу")
                            .font(.title2.bold())
                        Text(task.quadrant.subtitle)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 15) {
                    VStack(alignment: .leading, spacing: 7) {
                        Label("Название", systemImage: "text.cursor")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextField("Название задачи", text: $title)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.large)
                            .onSubmit(save)
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        Label("Описание", systemImage: "text.alignleft")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ZStack(alignment: .topLeading) {
                            if details.isEmpty {
                                Text("Добавьте контекст, детали или следующий шаг…")
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 9)
                                    .allowsHitTesting(false)
                            }

                            TextEditor(text: $details)
                                .font(.body)
                                .scrollContentBackground(.hidden)
                                .padding(4)
                                .accessibilityLabel("Описание")
                        }
                        .frame(minHeight: 110, maxHeight: 170)
                        .background(
                            Color.primary.opacity(0.035),
                            in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(Color.primary.opacity(0.16), lineWidth: 1)
                        }
                    }
                }
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 15))
                .overlay {
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(task.quadrant.tint.opacity(0.14), lineWidth: 1)
                }

                HStack(spacing: 10) {
                    Spacer()
                    Button("Отмена") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                        .controlSize(.large)
                    Button("Сохранить", systemImage: "checkmark", action: save)
                        .buttonStyle(.borderedProminent)
                        .tint(task.quadrant.tint)
                        .keyboardShortcut(.return, modifiers: [.command])
                        .controlSize(.large)
                        .disabled(normalizedTitle.isEmpty)
                }
            }
            .padding(26)
        }
        .frame(width: 500)
    }

    private func save() {
        guard !normalizedTitle.isEmpty else { return }
        task.title = normalizedTitle
        task.details = normalizedDetails
        try? modelContext.save()
        dismiss()
    }
}
