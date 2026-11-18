import SwiftUI

@main
struct NutriRatioApp: App {
    @State private var profileStore = ProfileStore()
    @State private var historyStore = HistoryStore()
    @State private var foodLibrary = FoodLibrary()
    @State private var recipeStore = RecipeStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(profileStore)
                .environment(historyStore)
                .environment(foodLibrary)
                .environment(recipeStore)
                .tint(.green)
        }
    }
}
