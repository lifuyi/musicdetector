//
//  KeyAdjustmentView.swift
//  Key adjustment UI for music analysis
//

import SwiftUI

struct KeyAdjustmentView: View {
    let currentKey: String
    let currentScale: String
    let onKeyAdjusted: (String, String) -> Void
    let onCancel: () -> Void
    
    @State private var selectedKey: String
    @State private var selectedScale: String
    
    private let keys = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    private let scales = ["major", "minor"]
    
    init(currentKey: String, currentScale: String, onKeyAdjusted: @escaping (String, String) -> Void, onCancel: @escaping () -> Void) {
        self.currentKey = currentKey
        self.currentScale = currentScale
        self.onKeyAdjusted = onKeyAdjusted
        self.onCancel = onCancel
        _selectedKey = State(initialValue: currentKey)
        _selectedScale = State(initialValue: currentScale)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Adjust Key Detection")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("Confidence in automatic detection was low. You can manually adjust the key.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Key")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Picker("Key", selection: $selectedKey) {
                        ForEach(keys, id: \.self) { key in
                            Text(key).tag(key)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(width: 100)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Scale")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Picker("Scale", selection: $selectedScale) {
                        ForEach(scales, id: \.self) { scale in
                            Text(scale.capitalized).tag(scale)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(width: 100)
                }
            }
            .padding(.vertical, 8)
            
            HStack(spacing: 12) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                
                Button(action: {
                    onKeyAdjusted(selectedKey, selectedScale)
                }) {
                    Text("Apply")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedKey == currentKey && selectedScale == currentScale)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(10)
    }
}