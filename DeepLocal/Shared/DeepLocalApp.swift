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
            ContentView()
        }
    }
}

#if os(macOS)
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        ClipboardMonitor.shared.start()
        
        ClipboardMonitor.shared.onDoubleCopy = { text in
            // 通知を送るか、直接Serviceを操作する
            NotificationCenter.default.post(name: .doubleCopyDetected, object: text)
            
            // アプリを前面に持ってくる
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
#endif
