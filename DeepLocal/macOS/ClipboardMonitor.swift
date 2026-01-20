import Foundation
import SwiftUI
import Combine
#if os(macOS)
import AppKit
#endif

class ClipboardMonitor: ObservableObject {
    static let shared = ClipboardMonitor()
    
    #if os(macOS)
    private var lastChangeCount = NSPasteboard.general.changeCount
    private var lastCopyTime: Date = .distantPast
    private let doubleCopyThreshold: TimeInterval = 0.6 // 0.6秒以内の2回コピーで発動
    #endif
    
    var onDoubleCopy: ((String) -> Void)?
    
    private init() {}
    
    func start() {
        #if os(macOS)
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.checkPasteboard()
        }
        #endif
    }
    
    #if os(macOS)
    private func checkPasteboard() {
        let currentChangeCount = NSPasteboard.general.changeCount
        if currentChangeCount != lastChangeCount {
            lastChangeCount = currentChangeCount
            
            let now = Date()
            if now.timeIntervalSince(lastCopyTime) < doubleCopyThreshold {
                // 回数リセットして発動
                lastCopyTime = .distantPast
                if let copiedString = NSPasteboard.general.string(forType: .string), !copiedString.isEmpty {
                    DispatchQueue.main.async {
                        self.onDoubleCopy?(copiedString)
                    }
                }
            } else {
                lastCopyTime = now
            }
        }
    }
    #endif
}

extension Notification.Name {
    static let doubleCopyDetected = Notification.Name("doubleCopyDetected")
}
