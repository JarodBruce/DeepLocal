import Foundation
import MLX
import MLXLLM
import MLXLMCommon
import Hub

@Observable
class MLXService {
    static let shared = MLXService()

    var modelContainer: ModelContainer?
    var isModelLoaded = false
    var outputText = ""
    var isGenerating = false
    var modelDownloadProgress: Progress?
    
    // 現在選択されているモデルID
    var selectedModelId: String {
        didSet {
            UserDefaults.standard.set(selectedModelId, forKey: "selected_model_id")
            // モデルが変更されたらリロードが必要
            isModelLoaded = false
            modelContainer = nil
        }
    }

    // 利用可能なモデルのリスト
    static let availableModels = [
        "mlx-community/LFM2-350M-ENJP-MT-8bit",
        "mlx-community/Qwen3-0.6B-4bit",
        "mlx-community/SmolLM-135M-Instruct-4bit"
    ]

    init() {
        self.selectedModelId = UserDefaults.standard.string(forKey: "selected_model_id") ?? "mlx-community/LFM2-350M-ENJP-MT-8bit"
    }

    func loadModel() async throws {
        guard !isModelLoaded else { return }

        // GPUメモリ制限の設定 (1GB / 1024MB に変更してパフォーマンスを最適化)
        MLX.GPU.set(cacheLimit: 1024 * 1024 * 1024)

        let configuration = ModelConfiguration(id: selectedModelId)
        
        let factory = LLMModelFactory.shared
        let container = try await factory.loadContainer(
            hub: HubApi(),
            configuration: configuration
        ) { progress in
            Task { @MainActor in
                self.modelDownloadProgress = progress
            }
        }
        
        await MainActor.run {
            self.modelContainer = container
            self.isModelLoaded = true
        }
    }

    func translate(text: String) async throws -> String {
        guard let container = modelContainer else {
            // 自動的にロードを試みる
             try await loadModel()
             guard let container = modelContainer else {
                 throw NSError(domain: "MLXService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Model not loaded"])
             }
             return try await translate(text: text)
        }

        await MainActor.run {
            isGenerating = true
            outputText = ""
        }
        
        var fullOutput = ""

        // 入力の判定とシステムプロンプトの追加 (READMEの要件)
        // LFM2モデルの場合、システムプロンプトが必須
        var messages: [Chat.Message] = []
        if selectedModelId.contains("LFM2") {
            let systemPrompt = detectLanguage(text: text)
            messages.append(Chat.Message(role: .system, content: systemPrompt))
        }
        messages.append(Chat.Message(role: .user, content: text))
        
        let userInput = UserInput(chat: messages)

        // 推論の実行 (actorのperformを使用)
        let stream: AsyncStream<Generation> = try await container.perform { context in
            let lmInput = try await context.processor.prepare(input: userInput)
            // README推奨パラメータ
            let parameters = GenerateParameters(
                temperature: 0.5,
                topP: 1.0,
                repetitionPenalty: 1.05
            )
            return try MLXLMCommon.generate(input: lmInput, parameters: parameters, context: context)
        }
        
        for await event in stream {
            switch event {
            case .chunk(let text):
                fullOutput += text
                await MainActor.run {
                    self.outputText += text
                }
            case .info(let info):
                print("Generation info: \(info)")
            default:
                break
            }
        }

        await MainActor.run {
            isGenerating = false
        }
        
        return fullOutput
    }

    private func detectLanguage(text: String) -> String {
        // 簡単な判定: ひらがな、カタカナ、漢字が含まれていれば日本語とみなして英語へ翻訳
        let range = text.range(of: "\\p{Hiragana}|\\p{Katakana}|\\p{Han}", options: .regularExpression)
        return range != nil ? "Translate to English." : "Translate to Japanese."
    }
}
