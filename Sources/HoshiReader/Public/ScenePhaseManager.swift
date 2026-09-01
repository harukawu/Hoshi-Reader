//
//  ScenePhaseManager.swift
//  Hoshi Reader
//
//  Copyright © 2026 Manhhao.
//  SPDX-License-Identifier: GPL-3.0-or-later
//

public class ScenePhaseManager {    
    public static func didBecomeActive() {
        LocalFileServer.shared.endBackgroundTask()
        Task { @MainActor in
            LocalFileServer.shared.setAudioServer(enabled: HoshiConfig.config.enableLocalAudio)
        }
        if HoshiConfig.config.autoUpdateDictionaries {
            DictionaryManager.shared.autoUpdateDictionaries()
        }
    }
    
    public static func didEnterBackground() {
        LocalFileServer.shared.startBackgroundTask()
    }
}
