//
//  ContentView.swift
//  Main interface with unified player and analyzer
//

import SwiftUI

struct ContentView: View {
    @StateObject private var playerManager = AudioPlayerManager()
    @StateObject private var analysisEngine = RealTimeAnalysisEngine()
    @StateObject private var inputManager = AudioInputManager()
    
    @State private var selectedTab: TabType = .player
    
    enum TabType: String, CaseIterable {
        case player = "Player & Analyzer"
        case microphone = "Microphone"
        case export = "Export"
        
        var icon: String {
            switch self {
            case .player: return "play.circle.fill"
            case .microphone: return "mic.circle.fill"
            case .export: return "square.and.arrow.up.circle.fill"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Selector
                TabSelectorView(selectedTab: $selectedTab)
                
                Divider()
                
                // Tab Content
                TabView(selection: $selectedTab) {
                    // Unified Player & Analyzer Tab
                    UnifiedPlayerAnalyzerView(
                        playerManager: playerManager,
                        analysisEngine: analysisEngine
                    )
                    .tag(TabType.player)
                    
                    // Microphone Input Tab
                    InputSourceView(
                        inputManager: inputManager,
                        analysisEngine: analysisEngine
                    )
                    .tag(TabType.microphone)
                    
                    // Export Tab
                    ExportView()
                        .tag(TabType.export)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Essentia Music Analyzer")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            setupAnalysisEngine()
        }
    }
    
    private func setupAnalysisEngine() {
        // Configure analysis engine settings
        analysisEngine.configure(
            bufferSize: 1024,
            hopSize: 512,
            sampleRate: 44100
        )
    }
}

// MARK: - Tab Selector View

struct TabSelectorView: View {
    @Binding var selectedTab: ContentView.TabType
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(ContentView.TabType.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.title2)
                            .foregroundColor(selectedTab == tab ? .blue : .secondary)
                        
                        Text(tab.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(selectedTab == tab ? .blue : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        selectedTab == tab ? 
                        Color.blue.opacity(0.1) : 
                        Color.clear
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(Color.secondary.opacity(0.05))
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
