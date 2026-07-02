import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: DataStore
    @State private var newDisliked = ""
    @State private var newAvoided  = ""
    @State private var tokenVisible = false
    @State private var showTokenInfo = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {

                        // --- Ernaehrungsziele ---
                        SectionCard(title: "Ernährungsziele") {
                            VStack(spacing: 16) {
                                HStack {
                                    Label("Kalorien / Tag", systemImage: "flame")
                                        .foregroundColor(.textPrimary)
                                    Spacer()
                                    Text("\(store.settings.dailyCalories) kcal")
                                        .foregroundColor(.accentGold).fontWeight(.semibold)
                                }
                                Slider(
                                    value: Binding(
                                        get: { Double(store.settings.dailyCalories) },
                                        set: { store.settings.dailyCalories = Int($0) }
                                    ),
                                    in: 1200...4000, step: 50
                                )
                                .accentColor(.accentGold)
                                .onChange(of: store.settings.dailyCalories) { _, _ in store.saveSettings() }

                                Divider().background(Color.divider)

                                HStack {
                                    Label("Mahlzeiten / Tag", systemImage: "fork.knife")
                                        .foregroundColor(.textPrimary)
                                    Spacer()
                                    Picker("", selection: $store.settings.mealsPerDay) {
                                        Text("2").tag(2); Text("3").tag(3); Text("4").tag(4)
                                    }
                                    .pickerStyle(.segmented)
                                    .frame(width: 120)
                                    .onChange(of: store.settings.mealsPerDay) { _, _ in store.saveSettings() }
                                }

                                Divider().background(Color.divider)

                                HStack {
                                    Label("Ernährungsweise", systemImage: "leaf")
                                        .foregroundColor(.textPrimary)
                                    Spacer()
                                    Picker("", selection: $store.settings.dietaryPreference) {
                                        ForEach(DietaryPreference.allCases, id: \.self) {
                                            Text($0.rawValue).tag($0)
                                        }
                                    }
                                    .pickerStyle(.menu).accentColor(.accentGold)
                                    .onChange(of: store.settings.dietaryPreference) { _, _ in store.saveSettings() }
                                }
                            }
                        }

                        // --- KI-Modell ---
                        SectionCard(title: "KI-Modell") {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Alle Modelle sind über die kostenlose Hugging Face Inference API verfügbar. Mistral 7B liefert die besten Ergebnisse.")
                                    .font(.caption).foregroundColor(.textSecondary)

                                ForEach(HFModel.allCases, id: \.self) { model in
                                    Button {
                                        store.settings.hfModel = model
                                        store.saveSettings()
                                    } label: {
                                        HStack(spacing: 12) {
                                            ZStack {
                                                Circle()
                                                    .stroke(store.settings.hfModel == model ? Color.accentGold : Color.divider, lineWidth: 2)
                                                    .frame(width: 20, height: 20)
                                                if store.settings.hfModel == model {
                                                    Circle().fill(Color.accentGold).frame(width: 10, height: 10)
                                                }
                                            }
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(model.displayName)
                                                    .font(.callout).foregroundColor(.textPrimary)
                                                Text(model.modelId)
                                                    .font(.caption2)
                                                    .foregroundColor(.textSecondary)
                                                    .lineLimit(1)
                                            }
                                            Spacer()
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                            }
                        }

                        // --- Hugging Face Token ---
                        SectionCard(title: "Hugging Face Token") {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 6) {
                                    Image(systemName: "key").foregroundColor(.accentGold).font(.caption)
                                    Text("Read-Token von huggingface.co/settings/tokens")
                                        .font(.caption).foregroundColor(.textSecondary)
                                    Spacer()
                                    Button {
                                        showTokenInfo = true
                                    } label: {
                                        Text("Wo bekomme ich ihn?")
                                            .font(.caption).foregroundColor(.accentGold)
                                    }
                                }

                                HStack {
                                    Group {
                                        if tokenVisible {
                                            TextField("hf_...", text: $store.settings.apiKey)
                                        } else {
                                            SecureField("hf_...", text: $store.settings.apiKey)
                                        }
                                    }
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .foregroundColor(.textPrimary)
                                    .font(.system(.body, design: .monospaced))
                                    .onChange(of: store.settings.apiKey) { _, _ in store.saveSettings() }

                                    Button {
                                        tokenVisible.toggle()
                                    } label: {
                                        Image(systemName: tokenVisible ? "eye.slash" : "eye")
                                            .foregroundColor(.textSecondary)
                                    }
                                }
                                .padding(10)
                                .background(Color.elevatedCard)
                                .cornerRadius(10)

                                if !store.settings.apiKey.isEmpty {
                                    Label("Token gespeichert", systemImage: "checkmark.circle.fill")
                                        .font(.caption).foregroundColor(.accentGreen)
                                }
                            }
                        }

                        // --- Ungemochte Lebensmittel ---
                        SectionCard(title: "Ungemochte Lebensmittel") {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Werden so selten wie möglich eingeplant.")
                                    .font(.caption).foregroundColor(.textSecondary)
                                TagInputField(
                                    placeholder: "z.B. Rosenkohl hinzufügen",
                                    newValue: $newDisliked,
                                    tags: $store.settings.dislikedFoods,
                                    color: .accentBronze
                                ) { store.saveSettings() }
                            }
                        }

                        // --- Vermeiden ---
                        SectionCard(title: "Zu vermeiden (Allergien)") {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Werden strikt ausgeschlossen (Allergene, Unverträglichkeiten).")
                                    .font(.caption).foregroundColor(.textSecondary)
                                TagInputField(
                                    placeholder: "z.B. Gluten hinzufügen",
                                    newValue: $newAvoided,
                                    tags: $store.settings.avoidedFoods,
                                    color: .destructive
                                ) { store.saveSettings() }
                            }
                        }

                        Spacer(minLength: 40)
                    }
                    .padding()
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .alert("Hugging Face Token", isPresented: $showTokenInfo) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("1. huggingface.co aufrufen und kostenlos registrieren\n2. Unter Settings → Access Tokens → New Token\n3. Typ \"Read\" wählen und Token kopieren\n\nDer Free-Tier erlaubt ca. 1.000 Anfragen pro Tag.")
            }
        }
    }
}

// MARK: - Shared UI Components

struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.headline).foregroundColor(.textPrimary)
            content
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(14)
    }
}

struct TagInputField: View {
    let placeholder: String
    @Binding var newValue: String
    @Binding var tags: [String]
    let color: Color
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TextField(placeholder, text: $newValue)
                    .foregroundColor(.textPrimary)
                    .submitLabel(.done)
                    .onSubmit(addTag)
                Button(action: addTag) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(color).font(.title3)
                }
            }
            .padding(10).background(Color.elevatedCard).cornerRadius(10)

            if !tags.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        TagChip(text: tag, color: color) {
                            tags.removeAll { $0 == tag }
                            onSave()
                        }
                    }
                }
            }
        }
    }

    private func addTag() {
        let v = newValue.trimmingCharacters(in: .whitespaces)
        guard !v.isEmpty, !tags.contains(v) else { return }
        tags.append(v); newValue = ""; onSave()
    }
}

struct TagChip: View {
    let text: String; let color: Color; let onRemove: () -> Void
    var body: some View {
        HStack(spacing: 4) {
            Text(text).font(.caption).foregroundColor(.textPrimary)
            Button(action: onRemove) {
                Image(systemName: "xmark").font(.caption2).foregroundColor(color)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(color.opacity(0.15))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(color.opacity(0.4), lineWidth: 1))
        .cornerRadius(20)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let h = rows.map { $0.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0 }
            .reduce(0, +) + CGFloat(max(rows.count - 1, 0)) * spacing
        return CGSize(width: proposal.width ?? 0, height: h)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in computeRows(proposal: proposal, subviews: subviews) {
            var x = bounds.minX
            let rh = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            for sv in row {
                let s = sv.sizeThatFits(.unspecified)
                sv.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
                x += s.width + spacing
            }
            y += rh + spacing
        }
    }
    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubview]] {
        var rows: [[LayoutSubview]] = [[]]
        var x: CGFloat = 0
        let maxW = proposal.width ?? 0
        for sv in subviews {
            let w = sv.sizeThatFits(.unspecified).width
            if x + w > maxW && !rows[rows.count - 1].isEmpty { rows.append([]); x = 0 }
            rows[rows.count - 1].append(sv); x += w + spacing
        }
        return rows
    }
}
