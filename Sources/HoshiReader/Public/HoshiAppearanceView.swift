//
//  HoshiAppearanceView.swift
//  Hoshi Reader
//
//  Copyright © 2026 Manhhao.
//  SPDX-License-Identifier: GPL-3.0-or-later
//

import SwiftUI
import UniformTypeIdentifiers

public struct HoshiAppearanceView: View {
    @Environment(UserConfig.self) var userConfig: UserConfig
    @State private var isImportingFont = false
    @State private var importedFonts: [String] = []
    @State private var downloadingFont: String? = nil
    @State private var showingDeleteConfirmation = false
    @State private var fontToDelete: String? = nil
    
    public init() {}
    
    public var body: some View {
        @Bindable var userConfig = userConfig
        let fontSelection = Binding<String>(
            get: { userConfig.selectedFont },
            set: { newFont in
                guard downloadingFont == nil else { return }
                
                guard FontManager.downloadableFonts.contains(newFont),
                      !FontManager.shared.hasDownloadedFont(name: newFont) else {
                    userConfig.selectedFont = newFont
                    return
                }
                
                let previousFont = userConfig.selectedFont
                downloadingFont = newFont
                
                Task {
                    let success = await FontManager.downloadFont(newFont)
                    downloadingFont = nil
                    userConfig.selectedFont = success ? newFont : previousFont
                }
            }
        )
        List {
            Section("Text") {
                HStack {
                    Picker("Font", selection: fontSelection) {
                        ForEach(FontManager.defaultFonts, id: \.self) { font in
                            Text(font).tag(font)
                        }
                        ForEach(FontManager.downloadableFonts, id: \.self) { font in
                            Text(font).tag(font)
                        }
                        ForEach(importedFonts, id: \.self) { font in
                            Text(font).tag(font)
                        }
                    }
                    .disabled(downloadingFont != nil)
                    
                    if !FontManager.shared.isDefaultFont(name: userConfig.selectedFont) {
                        Button {
                            fontToDelete = userConfig.selectedFont
                            showingDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .confirmationDialog("", isPresented: $showingDeleteConfirmation, titleVisibility: .hidden) {
                            Button("Delete", role: .destructive) {
                                if let fontName = fontToDelete {
                                    try? FontManager.shared.deleteFont(name: fontName)
                                    userConfig.selectedFont = FontManager.defaultFonts[0]
                                    importedFonts = (try? FontManager.shared.storedFonts())?.map { $0.deletingPathExtension().lastPathComponent } ?? []
                                }
                            }
                        } message: {
                            if let fontName = fontToDelete {
                                Text("Delete \"\(fontName)\"?")
                            }
                        }
                    }
                    
                    if downloadingFont != nil {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                
                Button {
                    isImportingFont = true
                } label: {
                    Text("Import Font")
                }
                .fileImporter(
                    isPresented: $isImportingFont,
                    allowedContentTypes: [.font],
                    onCompletion: { result in
                        if case .success(let url) = result {
                            FontManager.shared.importFont(from: url)
                            importedFonts = (try? FontManager.shared.storedFonts())?.map { $0.deletingPathExtension().lastPathComponent } ?? []
                        }
                    }
                )
            }
            .hanaSettingsRow()
            
            Section("Popup") {
                VStack {
                    HStack {
                        Text("Width")
                        Spacer()
                        Text("\(userConfig.popupWidth)")
                            .fontWeight(.semibold)
                    }
                    Slider(value: .init(
                        get: { Double(userConfig.popupWidth) },
                        set: { userConfig.popupWidth = Int($0) }
                    ), in: 100...700, step: 10)
                    
                    HStack {
                        Text("Height")
                        Spacer()
                        Text("\(userConfig.popupHeight)")
                            .fontWeight(.semibold)
                    }
                    Slider(value: .init(
                        get: { Double(userConfig.popupHeight) },
                        set: { userConfig.popupHeight = Int($0) }
                    ), in: 100...800, step: 10)
                    
                    HStack {
                        Text("Scale")
                        Spacer()
                        Text("\(userConfig.popupScale, specifier: "%.2f")")
                            .fontWeight(.semibold)
                    }
                    Slider(value: Bindable(userConfig).popupScale, in: 0.8...1.5, step: 0.05)
                }
                
                Toggle("Disable Transparency", isOn: Bindable(userConfig).popupDisableTransparency)
                
                Toggle("Full-width", isOn: Bindable(userConfig).popupFullWidth)
                
                Toggle("Swipe to Dismiss", isOn: Bindable(userConfig).popupSwipeToDismiss)
                if userConfig.popupSwipeToDismiss {
                    VStack {
                        HStack {
                            Text("Swipe Threshold")
                            Spacer()
                            Text("\(userConfig.popupSwipeThreshold)")
                                .fontWeight(.semibold)
                        }
                        Slider(value: .init(
                            get: { Double(userConfig.popupSwipeThreshold) },
                            set: { userConfig.popupSwipeThreshold = Int($0) }
                        ), in: 20...80, step: 5)
                    }
                }
            }
            .hanaSettingsRow()
        }
        .hanaSettingsScreen()
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            importedFonts = (try? FontManager.shared.storedFonts())?.map { $0.deletingPathExtension().lastPathComponent } ?? []
        }
    }
}
