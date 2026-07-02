import SwiftUI

struct MealPlanView: View {
    @EnvironmentObject var store: DataStore
    @State private var numberOfDays = 7
    @State private var isGenerating  = false
    @State private var errorMessage: String? = nil
    @State private var showError    = false
    @State private var selectedDay: DayPlan? = nil

    private let service = HuggingFaceService()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {

                        GeneratorCard(
                            numberOfDays: $numberOfDays,
                            isGenerating: isGenerating,
                            hasToken: !store.settings.apiKey.isEmpty,
                            modelName: store.settings.hfModel.displayName,
                            onGenerate: generate
                        )

                        if let plan = store.currentPlan {
                            PlanHeaderView(plan: plan)
                            ForEach(plan.days) { day in
                                DayCard(day: day, dailyTarget: store.settings.dailyCalories)
                                    .onTapGesture { selectedDay = day }
                            }
                        } else if !isGenerating {
                            EmptyPlanView()
                        }

                        if isGenerating { GeneratingView() }

                        Spacer(minLength: 40)
                    }
                    .padding()
                }
            }
            .navigationTitle("Essensplan")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .sheet(item: $selectedDay) { DayDetailView(day: $0, recipes: store.recipes) }
            .alert("Fehler", isPresented: $showError, presenting: errorMessage) { _ in
                Button("OK", role: .cancel) {}
            } message: { Text($0) }
        }
    }

    private func generate() {
        guard !store.settings.apiKey.isEmpty else {
            errorMessage = "Bitte zuerst einen Hugging Face Token in den Einstellungen hinterlegen."
            showError = true
            return
        }
        isGenerating = true
        Task {
            do {
                let plan = try await service.generateMealPlan(
                    days: numberOfDays,
                    settings: store.settings,
                    recipes: store.recipes
                )
                await MainActor.run {
                    store.setCurrentPlan(plan)
                    store.generateShoppingList()   // Einkaufszettel automatisch aktualisieren
                    isGenerating = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError    = true
                    isGenerating = false
                }
            }
        }
    }
}

// MARK: - Generator Card

struct GeneratorCard: View {
    @Binding var numberOfDays: Int
    let isGenerating: Bool
    let hasToken: Bool
    let modelName: String
    let onGenerate: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Neuer Essensplan").font(.headline).foregroundColor(.textPrimary)
                    HStack(spacing: 4) {
                        Image(systemName: "cpu").font(.caption).foregroundColor(.textSecondary)
                        Text(modelName).font(.caption).foregroundColor(.textSecondary)
                    }
                }
                Spacer()
                Image(systemName: "sparkles").font(.title2).foregroundColor(.accentGold)
            }

            Divider().background(Color.divider)

            HStack {
                Text("Anzahl Tage").foregroundColor(.textPrimary)
                Spacer()
                HStack(spacing: 12) {
                    Button { numberOfDays = max(1,  numberOfDays - 1) } label: {
                        Image(systemName: "minus.circle").foregroundColor(.accentGold).font(.title3)
                    }
                    Text("\(numberOfDays)")
                        .font(.title3).fontWeight(.bold).foregroundColor(.accentGold).frame(width: 32, alignment: .center)
                    Button { numberOfDays = min(14, numberOfDays + 1) } label: {
                        Image(systemName: "plus.circle").foregroundColor(.accentGold).font(.title3)
                    }
                }
            }

            Button(action: onGenerate) {
                HStack(spacing: 8) {
                    if isGenerating {
                        ProgressView().progressViewStyle(.circular).tint(.appBackground)
                    } else {
                        Image(systemName: "wand.and.sparkles")
                    }
                    Text(isGenerating ? "Wird erstellt…" : "Plan erstellen").fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(!hasToken || isGenerating ? Color.accentGold.opacity(0.5) : Color.accentGold)
                .foregroundColor(.appBackground).cornerRadius(14)
            }
            .disabled(!hasToken || isGenerating)

            if !hasToken {
                Label("Hugging Face Token in Einstellungen erforderlich", systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundColor(.accentBronze)
            }
        }
        .padding(16).background(Color.cardBackground).cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.accentGold.opacity(0.25), lineWidth: 1))
    }
}

// MARK: - Plan Header

struct PlanHeaderView: View {
    let plan: MealPlan
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(plan.totalDays)-Tage-Plan").font(.title3).fontWeight(.bold).foregroundColor(.textPrimary)
                Text("Erstellt \(plan.generatedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption).foregroundColor(.textSecondary)
            }
            Spacer()
            Image(systemName: "calendar").font(.title2).foregroundColor(.accentGold)
        }
        .padding(14).background(Color.cardBackground).cornerRadius(12)
    }
}

// MARK: - Day Card

struct DayCard: View {
    let day: DayPlan; let dailyTarget: Int
    var ratio: Double { Double(day.totalCalories) / Double(max(dailyTarget, 1)) }
    var calorieColor: Color {
        if ratio > 1.12 { return .destructive }
        if ratio < 0.88 { return .accentGold }
        return .accentGreen
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Tag \(day.dayNumber)").font(.headline).fontWeight(.bold).foregroundColor(.textPrimary)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill").font(.caption)
                    Text("\(day.totalCalories) kcal").font(.subheadline).fontWeight(.semibold)
                }.foregroundColor(calorieColor)
            }
            .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 10)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.divider).frame(height: 3).cornerRadius(2)
                    Rectangle().fill(calorieColor)
                        .frame(width: geo.size.width * min(ratio, 1.0), height: 3).cornerRadius(2)
                }
            }
            .frame(height: 3).padding(.horizontal, 14)

            VStack(spacing: 0) {
                ForEach(day.meals) { meal in
                    MealRow(meal: meal)
                    if meal.id != day.meals.last?.id {
                        Divider().background(Color.divider).padding(.horizontal, 14)
                    }
                }
            }.padding(.top, 10).padding(.bottom, 4)

            HStack {
                Spacer()
                Text("Tippen für Details").font(.caption2).foregroundColor(.textSecondary)
                Image(systemName: "chevron.right").font(.caption2).foregroundColor(.textSecondary)
            }.padding(.horizontal, 14).padding(.bottom, 10)
        }
        .background(Color.cardBackground).cornerRadius(14)
    }
}

struct MealRow: View {
    let meal: PlannedMeal
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: meal.type.icon).foregroundColor(.accentGold).font(.subheadline).frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(meal.type.rawValue).font(.caption).foregroundColor(.textSecondary)
                    if meal.isUserRecipe {
                        Label("Eigenes Rezept", systemImage: "star.fill").font(.caption2).foregroundColor(.accentGold)
                    }
                }
                Text(meal.name).font(.callout).fontWeight(.medium).foregroundColor(.textPrimary).lineLimit(1)
            }
            Spacer()
            Text("\(meal.calories)").font(.caption).fontWeight(.semibold).foregroundColor(.textSecondary)
            Text("kcal").font(.caption2).foregroundColor(.textSecondary)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }
}

// DayDetailView und CookingView sind in CookingView.swift definiert.

// MARK: - Empty / Loading

struct EmptyPlanView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "calendar.badge.plus").font(.system(size: 48)).foregroundColor(.accentGold.opacity(0.5))
            Text("Noch kein Plan erstellt").font(.headline).foregroundColor(.textPrimary)
            Text("Wähle die Anzahl Tage und tippe auf „Plan erstellen".")
                .font(.callout).foregroundColor(.textSecondary).multilineTextAlignment(.center)
        }
        .padding(30).frame(maxWidth: .infinity).background(Color.cardBackground).cornerRadius(14)
    }
}

struct GeneratingView: View {
    @State private var dots = ""
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    var body: some View {
        HStack(spacing: 14) {
            ProgressView().progressViewStyle(.circular).tint(.accentGold)
            VStack(alignment: .leading, spacing: 3) {
                Text("KI erstellt deinen Plan\(dots)").font(.callout).fontWeight(.medium).foregroundColor(.textPrimary)
                Text("Saisonalität, Nährstoffe & Abwechslung werden berücksichtigt…")
                    .font(.caption).foregroundColor(.textSecondary)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground).cornerRadius(14)
        .onReceive(timer) { _ in dots = dots.count < 3 ? dots + "." : "" }
    }
}
