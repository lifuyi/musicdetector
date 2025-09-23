//
//  EssentiaDemoApp.swift
//  iOS Essentia 演示应用
//

import SwiftUI

@main
struct EssentiaDemoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // 初始化检查
                    print("Essentia 可用: \(AudioAnalyzer.shared.isAvailable)")
                    print("版本: \(AudioAnalyzer.shared.version)")
                }
        }
    }
}
