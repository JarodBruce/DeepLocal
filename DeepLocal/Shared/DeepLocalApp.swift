//
//  DeepLocalApp.swift
//  DeepLocal
//
//  Created by warpflow on 2026/01/19.
//

import SwiftUI

@main
struct DeepLocalApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView(mlxService: MLXService.shared)
        }
        
        #if os(macOS)
        MenuBarExtra("DeepLocal", systemImage: "arrow.left.arrow.right.circle") {
            Button("開く") {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }
            Divider()
            Button("終了") {
                NSApp.terminate(nil)
            }
        }
        #endif
    }
}

#if os(macOS)
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        ClipboardMonitor.shared.start()
        
        ClipboardMonitor.shared.onDoubleCopy = { text in
            // UI更新用に通知を飛ばす
            NotificationCenter.default.post(name: .doubleCopyDetected, object: text)
            
            // 自動翻訳を開始
            Task {
                do {
                    // モデルがロードされているか確認
                    if !MLXService.shared.isModelLoaded {
                        try await MLXService.shared.loadModel()
                    }
                    
                    // 翻訳実行 (バックグラウンドで開始)
                    let translationTask = Task {
                        return try await MLXService.shared.translate(text: text)
                    }
                    
                    // アプリを前面に持ってくる
                    await MainActor.run {
                        NSApp.activate(ignoringOtherApps: true)
                        
                        // ウィンドウが表示されていない場合は再表示を試みる
                        if NSApp.windows.filter({ $0.isVisible }).isEmpty {
                            // SwiftUIのWindowGroupウィンドウを再オープンするために標準的なリオープン処理を呼び出す
                            _ = NSApp.delegate?.applicationShouldHandleReopen?(NSApp, hasVisibleWindows: false)
                            
                            // 念のため全てのウィンドウに対し orderFront 実行
                            for window in NSApp.windows {
                                window.makeKeyAndOrderFront(nil)
                            }
                        } else {
                            for window in NSApp.windows where !window.isVisible {
                                window.makeKeyAndOrderFront(nil)
                            }
                            // 既に表示されている場合は最前面へ
                            NSApp.windows.first(where: { $0.isVisible })?.makeKeyAndOrderFront(nil)
                        }
                    }
                    
                    _ = try await translationTask.value
                } catch {
                    print("Translation error: \(error)")
                }
            }
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // ウィンドウを閉じてもアプリを終了せずメニューバーに常駐
    }
}
#endif
