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

        // GPUメモリ制限の設定 (2MB)
        MLX.GPU.set(cacheLimit: 2 * 1024 * 1024)

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

        // 入力の準備
        let messages = [Chat.Message(role: .user, content: text)]
        let userInput = UserInput(chat: messages)

        // 推論の実行 (actorのperformを使用)
        let stream: AsyncStream<Generation> = try await container.perform { context in
            let lmInput = try await context.processor.prepare(input: userInput)
            let parameters = GenerateParameters(temperature: 0.7)
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
}
