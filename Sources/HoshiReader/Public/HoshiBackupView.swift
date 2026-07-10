//
//  HoshiBackupView.swift
//  Hoshi Reader
//
//  Copyright © 2026 Manhhao.
//  SPDX-License-Identifier: GPL-3.0-or-later
//

import SwiftUI
import UniformTypeIdentifiers
import ZIPFoundation

public struct HoshiBackupView: View {
    static private let hoshiURL = URL(string: "hoshi://")!
    
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var exportURL: URL?
    @State private var target = ""
    @State private var isLoading = false
    @State private var loadingString = ""
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var isHoshiAvailable = false
    
    public init() {}
    
    public var body: some View {
        List {
            Section {
                Button("Backup") {
                    backupFolder(folder: "Dictionaries")
                }
                Button("Restore") {
                    target = "Dictionaries";
                    isImporting = true
                }
            } header: {
                Text("Dictionaries")
            } footer: {
                Text("Restoring will overwrite the current collection.")
            }
            .hanaSettingsRow()
            
            if isHoshiAvailable {
                Section {
                    Button("Open Hoshi Reader") {
                        UIApplication.shared.open(Self.hoshiURL)
                    }
                } header: {
                    Text("Import from Hoshi Reader")
                } footer: {
                    Text("Open Hoshi Reader, export dictionary data and import to Hana")
                }
                .hanaSettingsRow()
            }
        }
        .hanaSettingsScreen()
        .task {
            isHoshiAvailable = UIApplication.shared.canOpenURL(Self.hoshiURL)
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [UTType(filenameExtension: "hoshi")!]
        ) { result in
            if case .success(let url) = result {
                restoreFolder(from: url, to: target)
            }
        }
        .fileMover(isPresented: $isExporting, file: exportURL) { result in
            switch result {
            case .success:
                exportURL = nil
            case .failure:
                cleanup()
            }
        } onCancellation: {
            cleanup()
        }
        .overlay {
            if isLoading {
                LoadingOverlay(loadingString)
            }
        }
        .navigationTitle("Backup")
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func backupFolder(folder: String) {
        isLoading = true
        loadingString = "Archiving..."
        let directory = try! BookStorage.getAppDirectory().appendingPathComponent(folder)
        Task.detached {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let archiveName = "\(folder)_\(formatter.string(from: Date())).hoshi"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(archiveName)
            do {
                try FileManager.default.zipItem(at: directory, to: tempURL, shouldKeepParent: false, compressionMethod: .deflate)
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
                return
            }
            
            await MainActor.run {
                exportURL = tempURL
                isLoading = false
                isExporting = true
            }
        }
    }
    
    private func cleanup() {
        if let exportURL {
            try? FileManager.default.removeItem(at: exportURL)
        }
        exportURL = nil
    }
    
    private func restoreFolder(from url: URL, to folder: String) {
        guard url.startAccessingSecurityScopedResource() else { return }
        isLoading = true
        loadingString = "Restoring..."
        let destination = try! BookStorage.getAppDirectory().appendingPathComponent(folder)
        Task.detached {
            defer { url.stopAccessingSecurityScopedResource() }
            do {
                try? FileManager.default.removeItem(at: destination)
                try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
                try FileManager.default.unzipItem(at: url, to: destination)
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
                return
            }
            await MainActor.run {
                isLoading = false
                if folder == "Dictionaries" {
                    DictionaryManager.shared.loadDictionaries()
                    DictionaryManager.shared.rebuildLookupQuery()
                }
            }
        }
    }
}
