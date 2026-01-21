import Foundation
import MLX
import MLXLLM
import MLXLMCommon
import Hub

@Observable
class MLXService {
    static let shared = MLXService()

    struct ModelInfo: Identifiable, Hashable {
        let id: String
        let name: String
        let description: String
    }

    var modelContainer: ModelContainer?
    var isModelLoaded = false
    var outputText = ""
    var isGenerating = false
    var modelDownloadProgress: Progress?
    
    // 現在選択されているモデルID
    var selectedModelId: String = "mlx-community/LFM2-350M-ENJP-MT-8bit"

    // 利用可能なモデルのリスト
    static let availableModels: [ModelInfo] = [
        ModelInfo(id: "mlx-community/LFM2-350M-ENJP-MT-8bit", name: "LFM2-350M", description: "高速・双方向日本語翻訳モデル")
    ]

    init() {
        self.selectedModelId = "mlx-community/LFM2-350M-ENJP-MT-8bit"
    }

    func resetModel() {
        isModelLoaded = false
        modelContainer = nil
        outputText = ""
        modelDownloadProgress = nil
    }

    func loadModel() async throws {
        guard !isModelLoaded else { return }

        // GPUメモリ制限の設定 (400MB)
        MLX.GPU.set(cacheLimit: 400 * 1024 * 1024)

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

        // システムプロンプトの決定 (LFM2には必須)
        let systemPrompt = detectLanguage(text: text)

        // 入力の準備 (Chat形式でシステムプロンプトを付与)
        let messages = [
            Chat.Message(role: .system, content: systemPrompt),
            Chat.Message(role: .user, content: text)
        ]
        let userInput = UserInput(chat: messages)

        // 推論の実行 (actorのperformを使用)
        let stream: AsyncStream<Generation> = try await container.perform { context in
            let lmInput = try await context.processor.prepare(input: userInput)
            // README推奨パラメータ: temperature 0.5, repetition_penalty 1.05
            let parameters = GenerateParameters(temperature: 0.5, repetitionPenalty: 1.05)
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
