import SwiftUI

enum TaskQuadrant: Int, CaseIterable, Identifiable {
    case doNow
    case schedule
    case delegate
    case eliminate

    var id: Self { self }

    init(isImportant: Bool, isUrgent: Bool) {
        switch (isImportant, isUrgent) {
        case (true, true): self = .doNow
        case (true, false): self = .schedule
        case (false, true): self = .delegate
        case (false, false): self = .eliminate
        }
    }

    var title: String {
        switch self {
        case .doNow: "Сделать"
        case .schedule: "Запланировать"
        case .delegate: "Делегировать"
        case .eliminate: "Исключить"
        }
    }

    var subtitle: String {
        switch self {
        case .doNow: "Важно и срочно"
        case .schedule: "Важно, но не срочно"
        case .delegate: "Срочно, но не важно"
        case .eliminate: "Не важно и не срочно"
        }
    }

    var systemImage: String {
        switch self {
        case .doNow: "flame.fill"
        case .schedule: "calendar"
        case .delegate: "person.2.fill"
        case .eliminate: "archivebox.fill"
        }
    }

    var tint: Color {
        switch self {
        case .doNow: .red
        case .schedule: .blue
        case .delegate: .orange
        case .eliminate: .gray
        }
    }

    var isImportant: Bool {
        self == .doNow || self == .schedule
    }

    var isUrgent: Bool {
        self == .doNow || self == .delegate
    }
}
