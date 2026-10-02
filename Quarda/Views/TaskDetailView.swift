import Foundation
import SwiftUI

struct TaskDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let task: TaskItem
    @State private var showsEditor = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [task.quadrant.tint.opacity(0.14), Color.clear],
                startPoint: .topLeading,
                endPoint: .center
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 22) {
                header

                VStack(alignment: .leading, spacing: 10) {
                    Label("Описание", systemImage: "text.alignleft")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    if let details = task.details, !details.isEmpty {
                        LinkifiedText(content: details)
                    } else {
                        Text("Описание не добавлено")
                            .foregroundStyle(.tertiary)
                            .italic()
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
                .padding(17)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 15))
                .overlay {
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(task.quadrant.tint.opacity(0.14), lineWidth: 1)
                }

                HStack(spacing: 10) {
                    Spacer()
                    Button("Закрыть") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                        .controlSize(.large)
                    Button("Редактировать", systemImage: "pencil") {
                        showsEditor = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(task.quadrant.tint)
                    .controlSize(.large)
                }
            }
            .padding(26)
        }
        .frame(width: 560)
        .sheet(isPresented: $showsEditor) {
            EditTaskView(task: task)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 13) {
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

            VStack(alignment: .leading, spacing: 7) {
                Text(task.title)
                    .font(.title2.bold())
                    .textSelection(.enabled)

                HStack(spacing: 8) {
                    Text(task.quadrant.subtitle)
                        .font(.caption)
                        .foregroundStyle(task.quadrant.tint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(task.quadrant.tint.opacity(0.10), in: Capsule())

                    if task.isCompleted {
                        Label("Выполнено", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                }
            }

            Spacer()
        }
    }
}

private struct LinkifiedText: View {
    let content: String

    var body: some View {
        Text(attributedContent)
            .font(.body)
            .lineSpacing(4)
            .textSelection(.enabled)
    }

    private var attributedContent: AttributedString {
        var attributed = AttributedString(content)
        guard let detector = try? NSDataDetector(
            types: NSTextCheckingResult.CheckingType.link.rawValue
        ) else {
            return attributed
        }

        let fullRange = NSRange(content.startIndex..<content.endIndex, in: content)
        for match in detector.matches(in: content, range: fullRange) {
            guard let url = match.url,
                  let stringRange = Range(match.range, in: content),
                  let attributedRange = Range<AttributedString.Index>(
                    stringRange,
                    in: attributed
                  ) else {
                continue
            }

            attributed[attributedRange].link = url
            attributed[attributedRange].foregroundColor = .accentColor
            attributed[attributedRange].underlineStyle = .single
        }
        return attributed
    }
}
