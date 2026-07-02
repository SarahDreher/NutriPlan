import SwiftUI

// MARK: - Recipe List

struct RecipeListView: View {
    @EnvironmentObject var store: DataStore
    @State private var showAdd = false
    @State private var selected: Recipe? = nil
    @State private var search = ""

    var filtered: [Recipe] {
        search.isEmpty ? store.recipes :
        store.recipes.filter {
            $0.name.localizedCaseInsensitiveContains(search) ||
            $0.ingredients.joined().localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                Group {
                    if store.recipes.isEmpty {
                        EmptyRecipesView { showAdd = true }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(MealType.allCases, id: \.self) { cat in
                                    let list = filtered.filter { $0.category == cat }
                                    if !list.isEmpty {
                                        CategorySection(category: cat, recipes: list) { selected = $0 }
                                    }
                                }
                            }
                            .padding()
                            .searchable(text: $search, prompt: "Rezept oder Zutat suchen")
                        }
                    }
                }
            }
            .navigationTitle("Meine Rezepte")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: {
                        Image(systemName: "plus").foregroundColor(.accentGold).fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $showAdd) { AddRecipeView() }
            .sheet(item: $selected)       { RecipeDetailView(recipe: $0) }
        }
    }
}

struct CategorySection: View {
    let category: MealType; let recipes: [Recipe]; let onTap: (Recipe) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: category.icon).foregroundColor(.accentGold).font(.subheadline)
                Text(category.rawValue).font(.subheadline).fontWeight(.semibold).foregroundColor(.textSecondary)
            }.padding(.top, 4)
            ForEach(recipes) { r in RecipeRowCard(recipe: r).onTapGesture { onTap(r) } }
        }
    }
}

struct RecipeRowCard: View {
    let recipe: Recipe
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.accentGold.opacity(0.15)).frame(width: 48, height: 48)
                Image(systemName: recipe.category.icon).foregroundColor(.accentGold).font(.title3)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(recipe.name).font(.body).fontWeight(.medium).foregroundColor(.textPrimary)
                HStack(spacing: 12) {
                    Label("\(recipe.caloriesPerServing) kcal", systemImage: "flame.fill")
                        .font(.caption).foregroundColor(.textSecondary)
                    Label("\(recipe.prepTimeMinutes) Min.", systemImage: "clock")
                        .font(.caption).foregroundColor(.textSecondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundColor(.textSecondary)
        }
        .padding(14).background(Color.cardBackground).cornerRadius(12)
    }
}

// MARK: - Add Recipe

struct AddRecipeView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var category: MealType = .any
    @State private var calories = 400
    @State private var servings = 1
    @State private var prepTime = 30
    @State private var ingredientText = ""
    @State private var instructions = ""
    @State private var notes = ""

    var ingredients: [String] {
        ingredientText.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }
    var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && !ingredientText.isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 18) {
                        SectionCard(title: "Grundinfos") {
                            VStack(spacing: 14) {
                                FloatingTextField(label: "Rezeptname", text: $name)
                                HStack {
                                    Text("Kategorie").foregroundColor(.textPrimary)
                                    Spacer()
                                    Picker("", selection: $category) {
                                        ForEach(MealType.allCases, id: \.self) {
                                            Label($0.rawValue, systemImage: $0.icon).tag($0)
                                        }
                                    }
                                    .pickerStyle(.menu).accentColor(.accentGold)
                                }
                                Divider().background(Color.divider)
                                StepperRow(label: "Kalorien (gesamt)", value: $calories, range: 50...3000, step: 50, unit: "kcal")
                                StepperRow(label: "Portionen",         value: $servings, range: 1...10,   step: 1,  unit: "")
                                StepperRow(label: "Zubereitungszeit",  value: $prepTime, range: 5...300,  step: 5,  unit: "Min.")
                            }
                        }
                        SectionCard(title: "Zutaten") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Eine Zutat pro Zeile, z.B. \"200g Hähnchenbrust\"")
                                    .font(.caption).foregroundColor(.textSecondary)
                                TextEditor(text: $ingredientText)
                                    .frame(minHeight: 120).foregroundColor(.textPrimary)
                                    .scrollContentBackground(.hidden).background(Color.elevatedCard).cornerRadius(10).padding(4)
                            }
                        }
                        SectionCard(title: "Zubereitung") {
                            TextEditor(text: $instructions)
                                .frame(minHeight: 100).foregroundColor(.textPrimary)
                                .scrollContentBackground(.hidden).background(Color.elevatedCard).cornerRadius(10).padding(4)
                        }
                        SectionCard(title: "Notizen (optional)") {
                            TextEditor(text: $notes)
                                .frame(minHeight: 60).foregroundColor(.textPrimary)
                                .scrollContentBackground(.hidden).background(Color.elevatedCard).cornerRadius(10).padding(4)
                        }
                        Spacer(minLength: 40)
                    }
                    .padding()
                }
            }
            .navigationTitle("Rezept hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading)  { Button("Abbrechen") { dismiss() }.foregroundColor(.textSecondary) }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Speichern") {
                        store.addRecipe(Recipe(name: name.trimmingCharacters(in: .whitespaces), category: category,
                            calories: calories, servings: servings, prepTimeMinutes: prepTime,
                            ingredients: ingredients, instructions: instructions, notes: notes))
                        dismiss()
                    }
                    .foregroundColor(isValid ? .accentGold : .textSecondary).fontWeight(.semibold).disabled(!isValid)
                }
            }
        }
    }
}

// MARK: - Recipe Detail

struct RecipeDetailView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) var dismiss
    let recipe: Recipe
    @State private var showDeleteAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle().fill(Color.accentGold.opacity(0.15)).frame(width: 64, height: 64)
                                Image(systemName: recipe.category.icon).foregroundColor(.accentGold).font(.title2)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(recipe.name).font(.title2).fontWeight(.bold).foregroundColor(.textPrimary)
                                Text(recipe.category.rawValue).font(.subheadline).foregroundColor(.textSecondary)
                            }
                        }
                        .padding().frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.cardBackground).cornerRadius(14)

                        HStack(spacing: 0) {
                            StatTile(icon: "flame.fill", value: "\(recipe.caloriesPerServing)", unit: "kcal", color: .accentGold)
                            Divider().background(Color.divider).frame(height: 40)
                            StatTile(icon: "person.2",  value: "\(recipe.servings)",           unit: "Port.", color: .accentBronze)
                            Divider().background(Color.divider).frame(height: 40)
                            StatTile(icon: "clock",     value: "\(recipe.prepTimeMinutes)",    unit: "Min.",  color: .accentGreen)
                        }
                        .background(Color.cardBackground).cornerRadius(14)

                        if !recipe.ingredients.isEmpty {
                            SectionCard(title: "Zutaten") {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(recipe.ingredients, id: \.self) { ing in
                                        HStack(spacing: 10) {
                                            Circle().fill(Color.accentGold).frame(width: 6, height: 6)
                                            Text(ing).foregroundColor(.textPrimary).font(.callout)
                                        }
                                    }
                                }
                            }
                        }
                        if !recipe.instructions.isEmpty {
                            SectionCard(title: "Zubereitung") {
                                Text(recipe.instructions).foregroundColor(.textPrimary).lineSpacing(4)
                            }
                        }
                        if !recipe.notes.isEmpty {
                            SectionCard(title: "Notizen") {
                                Text(recipe.notes).foregroundColor(.textSecondary).italic()
                            }
                        }
                        Button(role: .destructive) { showDeleteAlert = true } label: {
                            Label("Rezept löschen", systemImage: "trash")
                                .foregroundColor(.destructive).frame(maxWidth: .infinity)
                                .padding().background(Color.destructive.opacity(0.1)).cornerRadius(12)
                        }
                        Spacer(minLength: 40)
                    }
                    .padding()
                }
            }
            .navigationTitle("Rezept").navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Fertig") { dismiss() }.foregroundColor(.accentGold) } }
            .alert("Rezept löschen?", isPresented: $showDeleteAlert) {
                Button("Löschen", role: .destructive) { store.deleteRecipe(recipe); dismiss() }
                Button("Abbrechen", role: .cancel) {}
            }
        }
    }
}

// MARK: - Small UI Components

struct EmptyRecipesView: View {
    let onAdd: () -> Void
    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "book.closed").font(.system(size: 56)).foregroundColor(.accentGold.opacity(0.6))
            Text("Noch keine Rezepte").font(.title3).fontWeight(.semibold).foregroundColor(.textPrimary)
            Text("Füge deine Lieblingsrezepte hinzu, damit die KI sie einplanen kann.")
                .font(.callout).foregroundColor(.textSecondary).multilineTextAlignment(.center).padding(.horizontal, 40)
            Button(action: onAdd) {
                Label("Erstes Rezept hinzufügen", systemImage: "plus")
                    .font(.callout).fontWeight(.semibold).foregroundColor(.appBackground)
                    .padding(.horizontal, 24).padding(.vertical, 12)
                    .background(Color.accentGold).cornerRadius(24)
            }
            Spacer()
        }
    }
}

struct StatTile: View {
    let icon: String; let value: String; let unit: String; let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundColor(color).font(.title3)
            Text(value).font(.headline).fontWeight(.bold).foregroundColor(.textPrimary)
            Text(unit).font(.caption2).foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
    }
}

struct FloatingTextField: View {
    let label: String; @Binding var text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundColor(.textSecondary)
            TextField(label, text: $text)
                .foregroundColor(.textPrimary).padding(10).background(Color.elevatedCard).cornerRadius(10)
        }
    }
}

struct StepperRow: View {
    let label: String; @Binding var value: Int; let range: ClosedRange<Int>; let step: Int; let unit: String
    var body: some View {
        HStack {
            Text(label).foregroundColor(.textPrimary)
            Spacer()
            HStack(spacing: 12) {
                Button { value = max(range.lowerBound, value - step) } label: {
                    Image(systemName: "minus.circle").foregroundColor(.accentGold)
                }
                Text(unit.isEmpty ? "\(value)" : "\(value) \(unit)")
                    .foregroundColor(.textPrimary).fontWeight(.medium).frame(minWidth: 72, alignment: .center)
                Button { value = min(range.upperBound, value + step) } label: {
                    Image(systemName: "plus.circle").foregroundColor(.accentGold)
                }
            }
        }
    }
}
