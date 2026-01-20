//
//  ContentView.swift
//  DeepLocal
//
//  Created by warpflow on 2026/01/19.
//

import SwiftUI

struct ContentView: View {
    @State private var sourceText: String = ""
    @State private var mlxService = MLXService()
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // ソーステキスト入力エリア
                TextEditor(text: $sourceText)
                    .frame(height: 150)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                    .placeholder(when: sourceText.isEmpty) {
                        Text("翻訳したいテキストを入力...")
                            .foregroundColor(.gray)
                            .padding(.leading, 5)
                            .padding(.top, 8)
                    }

                // ロード進捗表示
                if !mlxService.isModelLoaded {
                    VStack {
                        let fraction = mlxService.modelDownloadProgress?.fractionCompleted ?? 0
                        ProgressView(value: fraction) {
                            HStack {
                                Text("モデルを準備中...")
                                Spacer()
                                Text("\(Int(fraction * 100))%")
                            }
                            .font(.caption)
                        }
                        .padding(.horizontal)
                    }
                }

                // 翻訳ボタン
                Button(action: startTranslation) {
                    if mlxService.isGenerating {
                        ProgressView()
                    } else {
                        HStack {
                            Image(systemName: "arrow.left.arrow.right.circle.fill")
                            Text("翻訳する")
                        }
                        .fontWeight(.bold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(sourceText.isEmpty || mlxService.isGenerating || !mlxService.isModelLoaded)

                // 結果表示エリア
                VStack(alignment: .trailing, spacing: 8) {
                    if !mlxService.outputText.isEmpty {
                        Button(action: {
                            #if os(iOS)
                            UIPasteboard.general.string = mlxService.outputText
                            #elseif os(macOS)
                            let pasteboard = NSPasteboard.general
                            pasteboard.clearContents()
                            pasteboard.setString(mlxService.outputText, forType: .string)
                            #endif
                        }) {
                            Label("コピー", systemImage: "doc.on.doc")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                    }

                    ScrollView {
                        VStack(alignment: .leading) {
                            if mlxService.outputText.isEmpty {
                                Text("翻訳結果がここに表示されます")
                                    .foregroundColor(.secondary)
                            } else {
                                Text(mlxService.outputText)
                                    .textSelection(.enabled)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .padding()
            .task {
                do {
                    try await mlxService.loadModel()
                } catch {
                    errorMessage = "モデルのロードに失敗しました: \(error.localizedDescription)"
                }
            }
            .alert("エラー", isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") { errorMessage = nil }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }

    private func startTranslation() {
        Task {
            do {
                try await mlxService.translate(text: sourceText)
            } catch {
                errorMessage = "翻訳中にエラーが発生しました: \(error.localizedDescription)"
            }
        }
    }
}

// プレースホルダー表示用ヘルパー
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .topLeading,
        @ViewBuilder placeholder: () -> Content) -> some View {

        ZStack(alignment: alignment) {
            if shouldShow {
                placeholder()
            }
            self
        }
    }
}

#Preview {
    ContentView()
}
