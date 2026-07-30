//
//  HoshiRootModifier.swift
//  HoshiReader
//
//  Created by Haruka on 2026/7/9.
//

import SwiftUI

struct HoshiRootModifier: ViewModifier {
    let userConfig = UserConfig()
    let scenePhase: ScenePhase
    let scheme: String
    
    func body(content: Content) -> some View {
        content
            .environment(userConfig)
            .task {
                hoshiWarmup()
            }
            .onChange(of: scenePhase, initial: true) { _, phase in
                switch phase {
                case .active:
                    LocalFileServer.shared.endBackgroundTask()
                    Task { @MainActor in
                        LocalFileServer.shared.setAudioServer(enabled: userConfig.enableLocalAudio)
                    }
                    if userConfig.autoUpdateDictionaries {
                        DictionaryManager.shared.autoUpdateDictionaries()
                    }
                case .background:
                    LocalFileServer.shared.startBackgroundTask()
                default:
                    break
                }
            }
            .onChange(of: userConfig.enableLocalAudio) { _, _ in
                LocalFileServer.shared.setAudioServer(enabled: userConfig.enableLocalAudio)
            }
            .onOpenURL { url in
                handleAnkiURL(url, scheme: scheme)
            }
    }
    
    private func hoshiWarmup() {
        WebViewPreloader.shared.warmup()
        _ = DictionaryManager.shared
    }
    
    private func handleAnkiURL(_ url: URL, scheme: String) {
        if url.isFileURL {
            if url.pathExtension == "colpkg" || url.pathExtension == "apkg" {
                try? AnkiManager.shared.importAnkiBackup(from: url)
            }
            return
        }

        guard url.scheme == scheme else { return }
        if url.host == "ankiFetch" {
            AnkiManager.shared.fetch()
        } else if url.host == "ankiSuccess" {
            LocalFileServer.shared.clearMedia()
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let expression = components.queryItems?.first(where: { $0.name == "expression" })?.value {
                AnkiManager.shared.addWord(expression)
            }
            if #available(anyAppleOS 26, *) {
                NotificationCenter.default.post(
                    AnkiSuccessMessage()
                )
            }
        }
    }
}

public extension View {
    func hoshiRootModifier(scenePhase: ScenePhase, scheme: String) -> some View {
        modifier(HoshiRootModifier(scenePhase: scenePhase, scheme: scheme))
    }
}
