# NutriPlan – Setup-Anleitung

## Voraussetzungen
- Mac mit macOS 13 oder neuer
- Xcode 15 oder neuer (kostenlos im Mac App Store)
- iPhone mit iOS 17+ (oder Xcode-Simulator)
- Hugging Face Account (kostenlos) mit API Token

---

## Schritt 1: Hugging Face Token erstellen

1. Auf **huggingface.co** registrieren (kostenlos)
2. Oben rechts auf dein Profilbild → **Settings → Access Tokens**
3. **New Token** → Typ **"Read"** wählen → Namen eingeben → **Generate**
4. Token kopieren (beginnt mit `hf_...`)

Das ist alles – kein Abo, keine Kreditkarte nötig. Der Free-Tier erlaubt ca. 1.000 Anfragen/Tag.

---

## Schritt 2: Xcode-Projekt erstellen

1. Xcode öffnen → **"Create New Project"**
2. **iOS → App** → **Next**
3. Einstellungen:
   - **Product Name:** `NutriPlan`
   - **Organization Identifier:** z.B. `de.hnu.nutriplan`
   - **Interface:** SwiftUI
   - **Language:** Swift
4. Speicherort wählen → **Create**

---

## Schritt 3: Bestehende Dateien ersetzen / hinzufügen

1. Die von Xcode generierte `ContentView.swift` **löschen** (Rechtsklick → Delete → Move to Trash)
2. Im Projektnavigator (links) den `NutriPlan`-Ordner rechtsklicken → **"Add Files to NutriPlan…"**
3. Alle 7 Swift-Dateien aus diesem Ordner auswählen:
   - `Models.swift`
   - `DataStore.swift`
   - `HuggingFaceService.swift`
   - `SettingsView.swift`
   - `RecipeViews.swift`
   - `MealPlanView.swift`
   - `ContentView.swift`
4. Die `NutriPlanApp.swift` von Xcode durch die mitgelieferte ersetzen (Inhalt kopieren/einfügen)

---

## Schritt 4: App starten

1. Oben links in Xcode: **"iPhone 16"** als Simulator wählen
2. **Play ▶** drücken oder `Cmd + R`
3. App startet im Simulator

---

## Schritt 5: Token eintragen & loslegen

1. In der App → Tab **Einstellungen**
2. Unter **„Hugging Face Token"** deinen `hf_...`-Token eintragen
3. Optional: KI-Modell auswählen (Mistral 7B empfohlen)
4. Tab **Plan** → Tagesanzahl wählen → **„Plan erstellen"** tippen

**Erster Start:** Das Modell braucht beim ersten Aufruf ~20–30 Sekunden zum Laden (Cold Start).
Bei einer 503-Fehlermeldung einfach nochmal tippen.

---

## App-Funktionen

**Tab: Plan**
Tagesanzahl 1–14 wählen, KI erstellt personalisierten Essensplan.
Jeder Tag zeigt Kalorienbalken (grün = im Ziel, gold = zu wenig, rot = zu viel).
Tippen auf einen Tag zeigt alle Details: Beschreibung, Zutaten, Nährwerthinweise.

**Tab: Rezepte**
Lieblingsrezepte mit Zutaten, Kalorien, Zubereitungszeit und Anleitung hinzufügen.
Die KI baut sie automatisch in den Plan ein.

**Tab: Einstellungen**
- Kalorienziel (1200–4000 kcal, Slider)
- Mahlzeiten pro Tag (2 / 3 / 4)
- Ernährungsweise (Alles / Vegetarisch / Vegan / Pescetarisch)
- KI-Modell auswählen (Mistral 7B, Qwen 2.5, Zephyr, Phi-3.5)
- Ungemochte Lebensmittel → werden so selten wie möglich eingeplant
- Allergene/Vermiedenes → werden strikt ausgeschlossen
- Hugging Face Token

---

## Verfügbare KI-Modelle (alle kostenlos)

| Modell | Empfehlung |
|---|---|
| Mistral 7B Instruct v0.3 | Bestes Ergebnis, empfohlen |
| Qwen 2.5 7B Instruct | Sehr gut, gute Abwechslung |
| Zephyr 7B Beta | Zuverlässig |
| Phi-3.5 Mini Instruct | Schneller, etwas weniger detailliert |

---

## Häufige Probleme

**503-Fehler beim ersten Aufruf**
→ Modell lädt noch (Cold Start). Einfach 30 Sekunden warten und erneut tippen.

**401-Fehler**
→ Token prüfen. Muss mit `hf_` beginnen und Read-Berechtigung haben.

**"Signing requires a development team"**
→ Xcode → Projekt → Signing & Capabilities → Team auswählen (Apple-ID genügt).

**Plan enthält unvollständige Mahlzeiten**
→ Modell hat den JSON abgeschnitten. Weniger Tage wählen oder ein anderes Modell probieren.
