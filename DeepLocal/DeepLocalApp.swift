//
//  DeepLocalApp.swift
//  DeepLocal
//
//  Created by warpflow on 2026/01/19.
//

import SwiftUI
import AppIntents

@main
struct DeepLocalApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - App Intents

struct TranslateIntent: AppIntent {
    static var title: LocalizedStringResource = "Translate Text"
    static var description = IntentDescription("Translates text using DeepLocal's on-device LLM.")

    @Parameter(title: "Text", requestValueDialog: "What text would you like to translate?")
    var text: String

    static var parameterSummary: some ParameterSummary {
        Summary("Translate \(\.$text)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let service = MLXService.shared
        
        // Ensure model is loaded
        let result = try await service.translate(text: text)
        return .result(value: result)
    }
}

struct DeepLocalShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TranslateIntent(),
            phrases: [
                "Translate with \(.applicationName)",
                "Translate using \(.applicationName)"
            ],
            shortTitle: "Translate",
            systemImageName: "translate"
        )
    }
}
