import SwiftUI

// MARK: - Day Detail mit Mahlzeit-Auswahl

/// Ersetzt den bisherigen DayDetailView – zeigt alle Mahlzeiten des Tages
/// und ermöglicht, für jede Mahlzeit den Kochmodus zu öffnen.
struct DayDetailView: View {
    let day: DayPlan
    let recipes: [Recipe]
    @Environment(\.dismiss) var dismiss
    @State private var cookingMeal: PlannedMeal? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {

                        // Tages-Übersicht
                        DaySummaryBanner(day: day)

                        // Mahlzeiten
                        ForEach(day.meals) { meal in
                            MealSelectionCard(
                                meal: meal,
                                linkedRecipe: recipes.first { $0.id == meal.linkedRecipeId }
                            ) {
                                cookingMeal = meal
                            }
                        }

                        Spacer(minLength: 40)
                    }
                    .padding()
                }
            }
            .navigationTitle("Tag \(day.dayNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }.foregroundColor(.accentGold)
                }
            }
            .sheet(item: $cookingMeal) { meal in
                CookingView(
                    meal: meal,
                    linkedRecipe: recipes.first { $0.id == meal.linkedRecipeId }
                )
            }
        }
    }
}

// MARK: - Tages-Banner

struct DaySummaryBanner: View {
    let day: DayPlan
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "calendar").font(.title2).foregroundColor(.accentGold)
            VStack(alignment: .leading, spacing: 2) {
                Text("Tag \(day.dayNumber)").font(.headline).foregroundColor(.textPrimary)
                Text("\(day.meals.count) Mahlzeiten · \(day.totalCalories) kcal gesamt")
                    .font(.caption).foregroundColor(.textSecondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - Mahlzeit-Auswahlkarte

struct MealSelectionCard: View {
    let meal: PlannedMeal
    let linkedRecipe: Recipe?
    let onCook: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Header-Zeile
            HStack {
                Label(meal.type.rawValue, systemImage: meal.type.icon)
                    .font(.caption).fontWeight(.semibold).foregroundColor(.accentGold)
                Spacer()
                Text("\(meal.calories) kcal")
                    .font(.caption).fontWeight(.bold).foregroundColor(.textPrimary)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.accentGold.opacity(0.15)).cornerRadius(8)
            }

            Text(meal.name)
                .font(.title3).fontWeight(.bold).foregroundColor(.textPrimary)

            Text(meal.description)
                .font(.callout).foregroundColor(.textSecondary).lineSpacing(3).lineLimit(2)

            // Zutaten-Vorschau
            if !meal.ingredients.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(meal.ingredients.prefix(5), id: \.self) { ing in
                            Text(ing)
                                .font(.caption).foregroundColor(.textPrimary)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.elevatedCard).cornerRadius(8)
                        }
                        if meal.ingredients.count > 5 {
                            Text("+\(meal.ingredients.count - 5) mehr")
                                .font(.caption).foregroundColor(.textSecondary)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                        }
                    }
                }
            }

            Divider().background(Color.divider)

            // Aktions-Buttons
            HStack(spacing: 10) {
                if linkedRecipe != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill").font(.caption2).foregroundColor(.accentGold)
                        Text("Eigenes Rezept").font(.caption).foregroundColor(.accentGold)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.accentGold.opacity(0.1)).cornerRadius(8)
                }

                Spacer()

                // Kochen-Button
                Button(action: onCook) {
                    HStack(spacing: 6) {
                        Image(systemName: "frying.pan")
                        Text("Jetzt kochen")
                    }
                    .font(.callout).fontWeight(.semibold)
                    .foregroundColor(.appBackground)
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .background(Color.accentGold).cornerRadius(20)
                }
            }
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(14)
    }
}

// MARK: - Kochmodus

struct CookingView: View {
    let meal: PlannedMeal
    let linkedRecipe: Recipe?
    @Environment(\.dismiss) var dismiss

    // Zutaten-Checkliste
    @State private var checkedIngredients: Set<String> = []
    @State private var currentStep = 0

    // Wähle Zutaten und Anleitung aus dem verknüpften Rezept oder der KI-Antwort
    var ingredients: [String] {
        linkedRecipe?.ingredients.isEmpty == false
            ? linkedRecipe!.ingredients
            : meal.ingredients
    }

    var instructions: String {
        linkedRecipe?.instructions.isEmpty == false
            ? linkedRecipe!.instructions
            : ""
    }

    var steps: [String] {
        guard !instructions.isEmpty else { return [] }
        return instructions
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {

                        // Header
                        CookingHeader(meal: meal, recipe: linkedRecipe)

                        // Zutaten-Checkliste
                        SectionCard(title: "Zutaten abhaken") {
                            VStack(spacing: 0) {
                                ForEach(ingredients, id: \.self) { ing in
                                    IngredientCheckRow(
                                        ingredient: ing,
                                        isChecked: checkedIngredients.contains(ing)
                                    ) {
                                        withAnimation(.spring(response: 0.25)) {
                                            if checkedIngredients.contains(ing) {
                                                checkedIngredients.remove(ing)
                                            } else {
                                                checkedIngredients.insert(ing)
                                            }
                                        }
                                    }
                                    if ing != ingredients.last {
                                        Divider().background(Color.divider).padding(.leading, 44)
                                    }
                                }
                            }
                            // Fortschrittsanzeige
                            if !ingredients.isEmpty {
                                let ratio = Double(checkedIngredients.count) / Double(ingredients.count)
                                HStack {
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 3).fill(Color.divider).frame(height: 6)
                                            RoundedRectangle(cornerRadius: 3).fill(Color.accentGreen)
                                                .frame(width: geo.size.width * ratio, height: 6)
                                                .animation(.easeInOut, value: ratio)
                                        }
                                    }
                                    .frame(height: 6)
                                    Text("\(checkedIngredients.count)/\(ingredients.count)")
                                        .font(.caption2).foregroundColor(.textSecondary).frame(width: 36, alignment: .trailing)
                                }
                                .padding(.top, 10)
                            }
                        }

                        // Zubereitungsschritte
                        if !steps.isEmpty {
                            SectionCard(title: "Zubereitung") {
                                VStack(spacing: 16) {
                                    ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                                        StepRow(number: idx + 1, text: step, isActive: idx == currentStep) {
                                            withAnimation { currentStep = idx }
                                        }
                                    }
                                }
                            }
                        } else if !meal.description.isEmpty {
                            // KI hat keine strukturierten Schritte – freier Text
                            SectionCard(title: "Hinweis zur Zubereitung") {
                                Text(meal.description)
                                    .foregroundColor(.textPrimary).lineSpacing(5)
                            }
                        }

                        // Nährwerthinweis
                        if !meal.nutritionHighlights.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "leaf.fill").foregroundColor(.accentGreen)
                                Text(meal.nutritionHighlights)
                                    .font(.callout).foregroundColor(.textSecondary).italic()
                            }
                            .padding(14)
                            .background(Color.accentGreen.opacity(0.08))
                            .cornerRadius(12)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding()
                }
            }
            .navigationTitle("Kochen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }.foregroundColor(.accentGold)
                }
            }
        }
    }
}

// MARK: - Cooking Header

struct CookingHeader: View {
    let meal: PlannedMeal
    let recipe: Recipe?
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.accentGold.opacity(0.15)).frame(width: 52, height: 52)
                    Image(systemName: meal.type.icon).foregroundColor(.accentGold).font(.title3)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(meal.type.rawValue).font(.caption).foregroundColor(.textSecondary)
                    Text(meal.name).font(.title3).fontWeight(.bold).foregroundColor(.textPrimary)
                }
            }
            HStack(spacing: 16) {
                Label("\(meal.calories) kcal", systemImage: "flame.fill")
                    .font(.caption).foregroundColor(.accentGold)
                if let r = recipe {
                    Label("\(r.prepTimeMinutes) Min.", systemImage: "clock")
                        .font(.caption).foregroundColor(.textSecondary)
                    Label("\(r.servings) Port.", systemImage: "person.2")
                        .font(.caption).foregroundColor(.textSecondary)
                }
            }
        }
        .padding(16).background(Color.cardBackground).cornerRadius(14)
    }
}

// MARK: - Ingredient Check Row

struct IngredientCheckRow: View {
    let ingredient: String
    let isChecked: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(isChecked ? Color.accentGreen : Color.divider, lineWidth: 2)
                        .frame(width: 24, height: 24)
                    if isChecked {
                        Image(systemName: "checkmark")
                            .font(.caption).fontWeight(.bold).foregroundColor(.accentGreen)
                    }
                }
                Text(ingredient)
                    .font(.callout)
                    .foregroundColor(isChecked ? .textSecondary : .textPrimary)
                    .strikethrough(isChecked, color: .textSecondary)
                Spacer()
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Step Row

struct StepRow: View {
    let number: Int
    let text: String
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isActive ? Color.accentGold : Color.elevatedCard)
                        .frame(width: 30, height: 30)
                    Text("\(number)")
                        .font(.caption).fontWeight(.bold)
                        .foregroundColor(isActive ? .appBackground : .textSecondary)
                }
                Text(text)
                    .font(.callout).foregroundColor(isActive ? .textPrimary : .textSecondary)
                    .lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
