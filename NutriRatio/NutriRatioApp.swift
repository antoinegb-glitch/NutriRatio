import SwiftUI

@main
struct NutriRatioApp: App {
    @State private var profileStore = ProfileStore()
    @State private var historyStore = HistoryStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(profileStore)
                .environment(historyStore)
                .tint(.green)
        }
    }
}
