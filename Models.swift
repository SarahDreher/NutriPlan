import SwiftUI
import Foundation

// MARK: - App Theme

extension Color {
    static let appBackground   = Color(red: 0.07, green: 0.07, blue: 0.08)
    static let cardBackground  = Color(red: 0.13, green: 0.13, blue: 0.15)
    static let elevatedCard    = Color(red: 0.17, green: 0.17, blue: 0.19)
    static let accentGold      = Color(red: 0.79, green: 0.67, blue: 0.43)
    static let accentBronze    = Color(red: 0.55, green: 0.45, blue: 0.33)
    static let accentGreen     = Color(red: 0.42, green: 0.62, blue: 0.45)
    static let textPrimary     = Color(red: 0.96, green: 0.94, blue: 0.91)
    static let textSecondary   = Color(red: 0.60, green: 0.57, blue: 0.50)
    static let divider         = Color(red: 0.22, green: 0.22, blue: 0.25)
    static let destructive     = Color(red: 0.75, green: 0.30, blue: 0.25)
}

// MARK: - Hugging Face Models

enum HFModel: String, Codable, CaseIterable {
    case mistral7b = "mistralai/Mistral-7B-Instruct-v0.3"
    case qwen25    = "Qwen/Qwen2.5-7B-Instruct"
    case zephyr    = "HuggingFaceH4/zephyr-7b-beta"
    case phi35     = "microsoft/Phi-3.5-mini-instruct"

    var displayName: String {
        switch self {
        case .mistral7b: return "Mistral 7B (Empfohlen)"
        case .qwen25:    return "Qwen 2.5 7B"
        case .zephyr:    return "Zephyr 7B"
        case .phi35:     return "Phi-3.5 Mini (Schnell)"
        }
    }
    var modelId: String { rawValue }
}

// MARK: - User Settings

struct UserSettings: Codable {
    var dailyCalories: Int = 2000
    var mealsPerDay: Int = 3
    var dislikedFoods: [String] = []
    var avoidedFoods: [String] = []
    var apiKey: String = ""          // Hugging Face Token
    var dietaryPreference: DietaryPreference = .omnivore
    var hfModel: HFModel = .mistral7b
}

enum DietaryPreference: String, Codable, CaseIterable {
    case omnivore    = "Alles"
    case vegetarian  = "Vegetarisch"
    case vegan       = "Vegan"
    case pescatarian = "Pescetarisch"
}

// MARK: - Recipe

struct Recipe: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var category: MealType
    var calories: Int
    var servings: Int = 1
    var prepTimeMinutes: Int = 30
    var ingredients: [String]
    var instructions: String
    var notes: String = ""
    var createdAt: Date = Date()
    var caloriesPerServing: Int { calories / max(servings, 1) }
}

enum MealType: String, Codable, CaseIterable {
    case breakfast = "Frühstück"
    case lunch     = "Mittagessen"
    case dinner    = "Abendessen"
    case snack     = "Snack"
    case any       = "Flexibel"
    var icon: String {
        switch self {
        case .breakfast: return "sun.horizon"
        case .lunch:     return "sun.max"
        case .dinner:    return "moon.stars"
        case .snack:     return "leaf"
        case .any:       return "fork.knife"
        }
    }
}

// MARK: - Meal Plan

struct MealPlan: Identifiable, Codable {
    var id: UUID = UUID()
    var generatedAt: Date = Date()
    var days: [DayPlan]
    var totalDays: Int { days.count }
}

struct DayPlan: Identifiable, Codable {
    var id: UUID = UUID()
    var dayNumber: Int
    var totalCalories: Int
    var meals: [PlannedMeal]
}

struct PlannedMeal: Identifiable, Codable {
    var id: UUID = UUID()
    var type: MealType
    var name: String
    var description: String
    var calories: Int
    var ingredients: [String]
    var nutritionHighlights: String
    var isUserRecipe: Bool = false
    var linkedRecipeId: UUID? = nil
}

// MARK: - API Response Models

struct ClaudeMealPlanResponse: Codable {
    struct Day: Codable {
        let dayNumber: Int
        let totalCalories: Int
        let meals: [Meal]
    }
    struct Meal: Codable {
        let type: String
        let name: String
        let description: String
        let calories: Int
        let ingredients: [String]
        let nutritionHighlights: String
        let isUserRecipe: Bool
        let recipeId: String?
    }
    let days: [Day]
}
