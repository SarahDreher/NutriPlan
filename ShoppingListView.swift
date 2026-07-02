import SwiftUI

struct ShoppingListView: View {
    @EnvironmentObject var store: DataStore
    @State private var showDayPicker = false
    @State private var selectedDays: Int = 0   // 0 = alle Tage

    var open:    [ShoppingItem] { store.shoppingList.filter { !$0.isChecked } }
    var checked: [ShoppingItem] { store.shoppingList.filter {  $0.isChecked } }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                Group {
                    if store.currentPlan == nil {
                        NoPlanView()
                    } else if store.shoppingList.isEmpty {
                        EmptyShoppingView { showDayPicker = true }
                    } else {
                        listContent
                    }
                }
            }
            .navigationTitle("Einkaufszettel")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !store.shoppingList.isEmpty {
                        Button {
                            showDayPicker = true
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.accentGold)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !checked.isEmpty {
                        Button("Erledigte löschen") {
                            withAnimation { store.clearCheckedItems() }
                        }
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                    }
                }
            }
            .sheet(isPresented: $showDayPicker) {
                DayPickerSheet(
                    totalDays: store.currentPlan?.totalDays ?? 0,
                    selectedDays: $selectedDays
                ) {
                    let days = selectedDays == 0 ? nil : selectedDays
                    store.generateShoppingList(forDays: days)
                    showDayPicker = false
                }
            }
            .onAppear {
                // Beim ersten Mal automatisch aus dem gesamten Plan generieren
                if store.shoppingList.isEmpty && store.currentPlan != nil {
                    store.generateShoppingList()
                }
            }
        }
    }

    // MARK: - List Content

    private var listContent: some View {
        ScrollView {
            VStack(spacing: 16) {

                // Fortschritts-Header
                ProgressHeader(done: checked.count, total: store.shoppingList.count)

                // Offene Artikel
                if !open.isEmpty {
                    ShoppingSection(title: "Noch besorgen", items: open, store: store)
                }

                // Abgehakte Artikel
                if !checked.isEmpty {
                    ShoppingSection(title: "Erledigt ✓", items: checked, store: store, dimmed: true)
                }

                Spacer(minLength: 40)
            }
            .padding()
        }
    }
}

// MARK: - Progress Header

struct ProgressHeader: View {
    let done: Int
    let total: Int
    var ratio: Double { total > 0 ? Double(done) / Double(total) : 0 }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("\(done) von \(total) besorgt")
                    .font(.subheadline).foregroundColor(.textSecondary)
                Spacer()
                Text("\(Int(ratio * 100))%")
                    .font(.subheadline).fontWeight(.semibold).foregroundColor(.accentGold)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.divider).frame(height: 8)
                    RoundedRectangle(cornerRadius: 4).fill(Color.accentGold)
                        .frame(width: geo.size.width * ratio, height: 8)
                        .animation(.easeInOut, value: ratio)
                }
            }
            .frame(height: 8)
        }
        .padding(14)
        .background(Color.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - Shopping Section

struct ShoppingSection: View {
    let title: String
    let items: [ShoppingItem]
    let store: DataStore
    var dimmed: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline).fontWeight(.semibold)
                .foregroundColor(.textSecondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(items) { item in
                    ShoppingRow(item: item) {
                        withAnimation(.spring(response: 0.3)) {
                            store.toggleShoppingItem(item)
                        }
                    }
                    if item.id != items.last?.id {
                        Divider().background(Color.divider).padding(.leading, 52)
                    }
                }
            }
            .background(Color.cardBackground)
            .cornerRadius(12)
            .opacity(dimmed ? 0.65 : 1.0)
        }
    }
}

// MARK: - Shopping Row

struct ShoppingRow: View {
    let item: ShoppingItem
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 14) {
                // Checkbox
                ZStack {
                    Circle()
                        .stroke(item.isChecked ? Color.accentGreen : Color.divider, lineWidth: 2)
                        .frame(width: 26, height: 26)
                    if item.isChecked {
                        Image(systemName: "checkmark")
                            .font(.caption).fontWeight(.bold)
                            .foregroundColor(.accentGreen)
                    }
                }

                // Zutat
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.callout)
                        .foregroundColor(item.isChecked ? .textSecondary : .textPrimary)
                        .strikethrough(item.isChecked, color: .textSecondary)

                    // Tag-Badge
                    if !item.dayNumbers.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar").font(.caption2).foregroundColor(.textSecondary)
                            Text(dayLabel(item.dayNumbers))
                                .font(.caption2).foregroundColor(.textSecondary)
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func dayLabel(_ days: [Int]) -> String {
        if days.count == 1 { return "Tag \(days[0])" }
        if days.count <= 3 { return days.map { "Tag \($0)" }.joined(separator: ", ") }
        return "Tag \(days.first!)–\(days.last!)"
    }
}

// MARK: - Day Picker Sheet

struct DayPickerSheet: View {
    let totalDays: Int
    @Binding var selectedDays: Int
    let onGenerate: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                VStack(spacing: 24) {
                    Text("Für wie viele Tage soll der Einkaufszettel erstellt werden?")
                        .font(.callout).foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    VStack(spacing: 0) {
                        DayPickerRow(label: "Alle \(totalDays) Tage", selected: selectedDays == 0) {
                            selectedDays = 0
                        }
                        Divider().background(Color.divider)
                        ForEach(1...totalDays, id: \.self) { d in
                            DayPickerRow(label: "Nächste \(d) \(d == 1 ? "Tag" : "Tage")", selected: selectedDays == d) {
                                selectedDays = d
                            }
                            if d < totalDays { Divider().background(Color.divider) }
                        }
                    }
                    .background(Color.cardBackground)
                    .cornerRadius(14)
                    .padding(.horizontal)

                    Button(action: onGenerate) {
                        Text("Einkaufszettel erstellen")
                            .fontWeight(.semibold).foregroundColor(.appBackground)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Color.accentGold).cornerRadius(14)
                    }
                    .padding(.horizontal)

                    Spacer()
                }
                .padding(.top, 24)
            }
            .navigationTitle("Einkaufszettel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { dismiss() }.foregroundColor(.textSecondary)
                }
            }
        }
    }
}

struct DayPickerRow: View {
    let label: String; let selected: Bool; let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(label).foregroundColor(.textPrimary)
                Spacer()
                if selected {
                    Image(systemName: "checkmark").foregroundColor(.accentGold).fontWeight(.semibold)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty States

struct NoPlanView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "cart").font(.system(size: 48)).foregroundColor(.accentGold.opacity(0.5))
            Text("Noch kein Essensplan").font(.headline).foregroundColor(.textPrimary)
            Text("Erstelle zuerst einen Plan im Tab „Plan", dann wird hier automatisch ein Einkaufszettel generiert.")
                .font(.callout).foregroundColor(.textSecondary).multilineTextAlignment(.center).padding(.horizontal, 40)
        }
    }
}

struct EmptyShoppingView: View {
    let onGenerate: () -> Void
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "cart.badge.plus").font(.system(size: 52)).foregroundColor(.accentGold.opacity(0.6))
            Text("Einkaufszettel erstellen").font(.title3).fontWeight(.semibold).foregroundColor(.textPrimary)
            Text("Alle Zutaten aus deinem Essensplan werden automatisch zusammengestellt.")
                .font(.callout).foregroundColor(.textSecondary).multilineTextAlignment(.center).padding(.horizontal, 40)
            Button(action: onGenerate) {
                Label("Jetzt erstellen", systemImage: "sparkles")
                    .font(.callout).fontWeight(.semibold).foregroundColor(.appBackground)
                    .padding(.horizontal, 28).padding(.vertical, 13)
                    .background(Color.accentGold).cornerRadius(24)
            }
        }
    }
}
