import SwiftUI

struct ContentView: View {
    @StateObject private var store = DataStore()

    var body: some View {
        TabView {
            MealPlanView()
                .tabItem { Label("Plan",           systemImage: "calendar") }

            RecipeListView()
                .tabItem { Label("Rezepte",        systemImage: "book.closed") }

            ShoppingListView()
                .tabItem { Label("Einkauf",        systemImage: "cart") }

            SettingsView()
                .tabItem { Label("Einstellungen",  systemImage: "slider.horizontal.3") }
        }
        .environmentObject(store)
        .tint(.accentGold)
        .preferredColorScheme(.dark)
        .onAppear {
            let tabAppearance = UITabBarAppearance()
            tabAppearance.configureWithOpaqueBackground()
            tabAppearance.backgroundColor = UIColor(red: 0.10, green: 0.10, blue: 0.11, alpha: 1)
            UITabBar.appearance().standardAppearance   = tabAppearance
            UITabBar.appearance().scrollEdgeAppearance = tabAppearance

            let navAppearance = UINavigationBarAppearance()
            navAppearance.configureWithOpaqueBackground()
            navAppearance.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1)
            let titleColor = UIColor(red: 0.96, green: 0.94, blue: 0.91, alpha: 1)
            navAppearance.titleTextAttributes      = [.foregroundColor: titleColor]
            navAppearance.largeTitleTextAttributes = [.foregroundColor: titleColor]
            UINavigationBar.appearance().standardAppearance   = navAppearance
            UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
            UINavigationBar.appearance().compactAppearance    = navAppearance
        }
    }
}
