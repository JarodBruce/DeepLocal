//
//  iOSSpecificLogic.swift
//  DeepLocal
//

import Foundation

// iOS専用の追加機能（バックグラウンド動作やiOS固有の通知設定など）をここに記述します
class iOSSpecificLogic {
    static let shared = iOSSpecificLogic()
    private init() {}
    
    func setup() {
        print("iOS specific setup")
    }
}
