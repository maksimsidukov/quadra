import Foundation
import SwiftData

enum AppDataStore {
    static let directoryName = "ru.msidukov.Quarda"
    static let storeName = "tasks.store"

    @MainActor
    static func makeModelContainer() -> ModelContainer {
        do {
            let schema = Schema([TaskItem.self])
            let storeURL = try persistentStoreURL()
            return try makeModelContainer(schema: schema, at: storeURL)
        } catch {
            fatalError("Не удалось открыть хранилище задач: \(error.localizedDescription)")
        }
    }

    @MainActor
    static func makeModelContainer(at storeURL: URL) throws -> ModelContainer {
        try makeModelContainer(schema: Schema([TaskItem.self]), at: storeURL)
    }

    @MainActor
    private static func makeModelContainer(schema: Schema, at storeURL: URL) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "Quarda",
            schema: schema,
            url: storeURL
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private static func persistentStoreURL() throws -> URL {
        let applicationSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = applicationSupport.appendingPathComponent(
            directoryName,
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory.appendingPathComponent(storeName)
    }
}
