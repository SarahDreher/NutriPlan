import Foundation
import Combine

// MARK: - Shopping List Model

struct ShoppingItem: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String          // Zutat, z.B. "80g Haferflocken"
    var isChecked: Bool = false
    var dayNumbers: [Int]     // An welchen Tagen wird diese Zutat gebraucht
}

@MainActor
class DataStore: ObservableObject {
    @Published var recipes: [Recipe] = []
    @Published var settings: UserSettings = UserSettings()
    @Published var currentPlan: MealPlan? = nil
    @Published var savedPlans: [MealPlan] = []
    @Published var shoppingList: [ShoppingItem] = []

    private let recipesKey      = "nutriplan_recipes"
    private let settingsKey     = "nutriplan_settings"
    private let plansKey        = "nutriplan_plans"
    private let shoppingKey     = "nutriplan_shopping"

    init() { load() }

    // MARK: - Persistence

    func load() {
        if let d = UserDefaults.standard.data(forKey: recipesKey),
           let v = try? JSONDecoder().decode([Recipe].self, from: d) { recipes = v }
        if let d = UserDefaults.standard.data(forKey: settingsKey),
           let v = try? JSONDecoder().decode(UserSettings.self, from: d) { settings = v }
        if let d = UserDefaults.standard.data(forKey: plansKey),
           let v = try? JSONDecoder().decode([MealPlan].self, from: d) {
            savedPlans = v
            currentPlan = savedPlans.first
        }
        if let d = UserDefaults.standard.data(forKey: shoppingKey),
           let v = try? JSONDecoder().decode([ShoppingItem].self, from: d) { shoppingList = v }
    }

    func saveRecipes()   { if let d = try? JSONEncoder().encode(recipes)      { UserDefaults.standard.set(d, forKey: recipesKey) } }
    func saveSettings()  { if let d = try? JSONEncoder().encode(settings)     { UserDefaults.standard.set(d, forKey: settingsKey) } }
    func savePlans()     { if let d = try? JSONEncoder().encode(savedPlans)   { UserDefaults.standard.set(d, forKey: plansKey) } }
    func saveShopping()  { if let d = try? JSONEncoder().encode(shoppingList) { UserDefaults.standard.set(d, forKey: shoppingKey) } }

    // MARK: - Shopping List

    /// Generiert Einkaufszettel aus den nächsten `days` Tagen des aktuellen Plans
    func generateShoppingList(forDays days: Int? = nil) {
        guard let plan = currentPlan else { return }
        let relevantDays = days.map { Array(plan.days.prefix($0)) } ?? plan.days

        // Zutaten aller Mahlzeiten sammeln und nach Tagen gruppieren
        var ingredientMap: [String: [Int]] = [:]
        for day in relevantDays {
            for meal in day.meals {
                for ingredient in meal.ingredients {
                    let key = ingredient.trimmingCharacters(in: .whitespaces)
                    if !key.isEmpty {
                        ingredientMap[key, default: []].append(day.dayNumber)
                    }
                }
            }
        }

        shoppingList = ingredientMap.map { name, days in
            ShoppingItem(name: name, isChecked: false, dayNumbers: days.sorted())
        }.sorted { $0.name < $1.name }

        saveShopping()
    }

    func toggleShoppingItem(_ item: ShoppingItem) {
        if let i = shoppingList.firstIndex(where: { $0.id == item.id }) {
            shoppingList[i].isChecked.toggle()
            saveShopping()
        }
    }

    func clearCheckedItems() {
        shoppingList.removeAll { $0.isChecked }
        saveShopping()
    }

    // MARK: - Recipes

    func addRecipe(_ r: Recipe)    { recipes.append(r); saveRecipes() }
    func updateRecipe(_ r: Recipe) { if let i = recipes.firstIndex(where: { $0.id == r.id }) { recipes[i] = r; saveRecipes() } }
    func deleteRecipe(_ r: Recipe) { recipes.removeAll { $0.id == r.id }; saveRecipes() }

    // MARK: - Plans

    func setCurrentPlan(_ plan: MealPlan) {
        currentPlan = plan
        savedPlans.insert(plan, at: 0)
        if savedPlans.count > 10 { savedPlans = Array(savedPlans.prefix(10)) }
        savePlans()
    }

    func deletePlan(_ plan: MealPlan) {
        savedPlans.removeAll { $0.id == plan.id }
        if currentPlan?.id == plan.id { currentPlan = savedPlans.first }
        savePlans()
    }
}
