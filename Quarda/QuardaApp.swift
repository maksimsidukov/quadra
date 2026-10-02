import SwiftData
import SwiftUI

@main
struct QuardaApp: App {
    private let modelContainer: ModelContainer

    init() {
        modelContainer = AppDataStore.makeModelContainer()
    }

    var body: some Scene {
        WindowGroup {
            MatrixView()
        }
        .modelContainer(modelContainer)
        .defaultSize(width: 1_080, height: 760)
        .windowResizability(.contentMinSize)
        .windowStyle(.hiddenTitleBar)
    }
}
