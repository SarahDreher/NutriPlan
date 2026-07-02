import Foundation

// MARK: - Errors

enum LLMError: LocalizedError {
    case missingToken
    case networkError(String)
    case invalidResponse
    case modelLoading
    case parseError(String)
    case apiError(Int, String)

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "Kein Hugging Face Token hinterlegt. Bitte unter Einstellungen eintragen."
        case .networkError(let m):
            return "Netzwerkfehler: \(m)"
        case .invalidResponse:
            return "Ungültige Antwort vom Server."
        case .modelLoading:
            return "Das Modell wird noch geladen (Cold Start). Bitte in ~30 Sekunden erneut versuchen."
        case .parseError(let m):
            return "Antwort konnte nicht verarbeitet werden: \(m)"
        case .apiError(let code, let msg):
            return "API-Fehler \(code): \(msg)"
        }
    }
}

// MARK: - Hugging Face Service
//
// Verwendet den OpenAI-kompatiblen Inference-Endpunkt von Hugging Face.
// Dokumentation: https://huggingface.co/docs/api-inference/tasks/chat-completion
// Token: https://huggingface.co/settings/tokens (Read-Berechtigung genügt)

class HuggingFaceService {

    private let endpoint = "https://api-inference.huggingface.co/v1/chat/completions"

    func generateMealPlan(
        days: Int,
        settings: UserSettings,
        recipes: [Recipe]
    ) async throws -> MealPlan {

        let token = settings.apiKey.trimmingCharacters(in: .whitespaces)
        guard !token.isEmpty else { throw LLMError.missingToken }

        let requestBody: [String: Any] = [
            "model": settings.hfModel.modelId,
            "messages": [
                [
                    "role": "system",
                    "content": "Du bist ein Ernaehrungsberater. Antworte ausschliesslich mit validem JSON ohne Markdown-Formatierung."
                ],
                [
                    "role": "user",
                    "content": buildPrompt(days: days, settings: settings, recipes: recipes)
                ]
            ],
            "max_tokens": 6000,
            "temperature": 0.7,
            "stream": false
        ]

        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.timeoutInterval = 120       // HF-Modelle brauchen beim Kaltstart laenger
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)",   forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw LLMError.networkError(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        // 503 = Modell laedt (HF Cold Start)
        if http.statusCode == 503 { throw LLMError.modelLoading }

        if http.statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? "–"
            throw LLMError.apiError(http.statusCode, body)
        }

        // OpenAI-kompatibles Response-Format parsen
        guard
            let json     = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices  = json["choices"] as? [[String: Any]],
            let first    = choices.first,
            let message  = first["message"] as? [String: Any],
            let content  = message["content"] as? String
        else {
            throw LLMError.invalidResponse
        }

        let jsonString = extractJSON(from: content)
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw LLMError.parseError("Leerer JSON-String in Modellantwort")
        }

        do {
            let decoded = try JSONDecoder().decode(ClaudeMealPlanResponse.self, from: jsonData)
            return convertToPlan(decoded, recipes: recipes)
        } catch {
            throw LLMError.parseError(error.localizedDescription)
        }
    }

    // MARK: - Prompt

    private func buildPrompt(days: Int, settings: UserSettings, recipes: [Recipe]) -> String {
        let season   = currentSeason()
        let avoided  = settings.avoidedFoods.isEmpty  ? "keine" : settings.avoidedFoods.joined(separator: ", ")
        let disliked = settings.dislikedFoods.isEmpty ? "keine" : settings.dislikedFoods.joined(separator: ", ")
        let mealStr  = mealNames(settings.mealsPerDay)
        let recipeStr = recipeSummaries(recipes)

        // Kompaktes JSON-Beispiel als Referenz
        let exampleJSON = """
{"days":[{"dayNumber":1,"totalCalories":1950,"meals":[{"type":"breakfast","name":"Haferbrei mit Beeren","description":"Cremiger Haferbrei mit frischen Heidelbeeren","calories":380,"ingredients":["80g Haferflocken","250ml Hafermilch","100g Heidelbeeren","1 TL Honig"],"nutritionHighlights":"Ballaststoffreich, langanhaltende Energie","isUserRecipe":false,"recipeId":null}]}]}
"""

        return """
Erstelle einen \(days)-Tage-Ernaehrungsplan fuer folgende Person:

EINSTELLUNGEN:
- Kalorienziel pro Tag: \(settings.dailyCalories) kcal
- Ernaehrungsweise: \(settings.dietaryPreference.rawValue)
- Mahlzeiten pro Tag: \(settings.mealsPerDay) (\(mealStr))
- Strikt vermeiden (Allergien/Unvertraeglichkeiten): \(avoided)
- Ungemochte Lebensmittel: \(disliked)
- Jahreszeit: \(season)

LIEBLINGSREZEPTE:
\(recipeStr.isEmpty ? "Keine vorhanden." : recipeStr)

REGELN:
1. Kalorienziel \(settings.dailyCalories) kcal/Tag einhalten (plus minus 10 Prozent)
2. Ausgewogene Makronaehrstoffe: Protein, Kohlenhydrate, gesunde Fette, Ballaststoffe
3. Saisonale Lebensmittel fuer \(season) bevorzugen
4. Jede Mahlzeit darf sich im gesamten Plan nur einmal vorkommen
5. Vermiedene/allergene Lebensmittel STRIKT ausschliessen
6. Lieblingsrezepte einbauen wenn passend (isUserRecipe: true, recipeId auf die ID setzen)

Antworte NUR mit validem JSON in exakt diesem Format (kein Text davor oder danach):
\(exampleJSON)

Erlaubte Werte fuer "type": "breakfast", "lunch", "dinner", "snack"
Erstelle \(days) Tage mit je \(settings.mealsPerDay) Mahlzeiten.
"""
    }

    // MARK: - Helpers

    private func mealNames(_ count: Int) -> String {
        switch count {
        case 2:  return "Fruehstueck, Abendessen"
        case 4:  return "Fruehstueck, Mittagessen, Abendessen, Snack"
        default: return "Fruehstueck, Mittagessen, Abendessen"
        }
    }

    private func recipeSummaries(_ recipes: [Recipe]) -> String {
        guard !recipes.isEmpty else { return "" }
        return recipes.map {
            "- ID:\($0.id.uuidString) | \($0.name) (\($0.category.rawValue), \($0.caloriesPerServing) kcal/Portion) | Zutaten: \($0.ingredients.prefix(4).joined(separator: ", "))"
        }.joined(separator: "\n")
    }

    private func currentSeason() -> String {
        switch Calendar.current.component(.month, from: Date()) {
        case 3...5:  return "Fruehling"
        case 6...8:  return "Sommer"
        case 9...11: return "Herbst"
        default:     return "Winter"
        }
    }

    private func extractJSON(from text: String) -> String {
        var s = text
        for fence in ["```json\n", "```\n"] {
            if let r = s.range(of: fence) { s = String(s[r.upperBound...]) }
        }
        if let r = s.range(of: "\n```") { s = String(s[..<r.lowerBound]) }
        if let start = s.firstIndex(of: "{"), let end = s.lastIndex(of: "}") {
            return String(s[start...end])
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func convertToPlan(_ r: ClaudeMealPlanResponse, recipes: [Recipe]) -> MealPlan {
        let days = r.days.map { d in
            let meals = d.meals.map { m in
                PlannedMeal(
                    type: mealType(m.type),
                    name: m.name,
                    description: m.description,
                    calories: m.calories,
                    ingredients: m.ingredients,
                    nutritionHighlights: m.nutritionHighlights,
                    isUserRecipe: m.isUserRecipe,
                    linkedRecipeId: m.recipeId.flatMap { UUID(uuidString: $0) }
                )
            }
            return DayPlan(dayNumber: d.dayNumber, totalCalories: d.totalCalories, meals: meals)
        }
        return MealPlan(days: days)
    }

    private func mealType(_ s: String) -> MealType {
        switch s.lowercased() {
        case "breakfast": return .breakfast
        case "lunch":     return .lunch
        case "dinner":    return .dinner
        case "snack":     return .snack
        default:          return .any
        }
    }
}

// Alias fuer Kompatibilitaet mit MealPlanView (der private let claudeService = ClaudeService() nutzt)
typealias ClaudeService = HuggingFaceService
