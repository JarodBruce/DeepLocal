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
    var selectedModelId: String {
        didSet {
            if oldValue != selectedModelId {
                UserDefaults.standard.set(selectedModelId, forKey: "selected_model_id")
                // モデルが変更されたらリロードが必要
                resetModel()
            }
        }
    }

    // 利用可能なモデルのリスト
    static let availableModels: [ModelInfo] = [
        ModelInfo(id: "mlx-community/LFM2-350M-ENJP-MT-8bit", name: "標準 (LFM2-350M)", description: "高速でバランスの良い標準モデル"),
        ModelInfo(id: "mlx-community/Llama-3.2-3B-Instruct-4bit", name: "高精度 (Llama-3.2-3B)", description: "より文脈を理解する高精度な3Bモデル"),
        ModelInfo(id: "mlx-community/Qwen2.5-7B-Instruct-4bit", name: "最高精度 (Qwen2.5-7B)", description: "最高品質だが動作が重い7Bモデル"),
        ModelInfo(id: "mlx-community/SmolLM-135M-Instruct-4bit", name: "超軽量 (SmolLM-135M)", description: "速度を最優先した超軽量モデル")
    ]

    init() {
        self.selectedModelId = UserDefaults.standard.string(forKey: "selected_model_id") ?? "mlx-community/LFM2-350M-ENJP-MT-8bit"
    }

    func resetModel() {
        isModelLoaded = false
        modelContainer = nil
        outputText = ""
        modelDownloadProgress = nil
    }

    func loadModel() async throws {
        guard !isModelLoaded else { return }

        // GPUメモリ制限の設定 (1GB に変更してパフォーマンスを最適化)
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

        // 入力の判定とシステムプロンプトの追加
        let translationInstruction = detectLanguage(text: text)
        var systemPrompt = translationInstruction
        
        // LFM2以外の汎用Instructモデル（Llama, Qwen, SmolLMなど）の場合
        // 翻訳結果のみを出力するように指示を強化する
        // 英語 -> 日本語（Translate to Japanese.）の際に特に重要
        if !selectedModelId.contains("LFM2") {
            systemPrompt += " Output ONLY the translated text. Do not include any explanations, introductory remarks, or conversational filler. Your response should contain only the direct translation."
        }
        
        var messages: [Chat.Message] = [
            Chat.Message(role: .system, content: systemPrompt),
            Chat.Message(role: .user, content: text)
        ]
        
        let userInput = UserInput(chat: messages)

        // 推論の実行 (actorのperformを使用)
        let stream: AsyncStream<Generation> = try await container.perform { context in
            let lmInput = try await context.processor.prepare(input: userInput)
            // 推論パラメータ
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
