//
//  HoshiConfig.swift
//  Hoshi Reader
//
//  Copyright © 2026 Manhhao.
//  SPDX-License-Identifier: GPL-3.0-or-later
//

import SwiftUI

struct HoshiConfig {
    static let config = UserConfig()
}

private struct ObserveAudioToggleChangeModifier: ViewModifier {
    @State var userConfig = HoshiConfig.config
    
    func body(content: Content) -> some View {
        content
            .onChange(of: userConfig.enableLocalAudio) { _, _ in
                LocalFileServer.shared.setAudioServer(enabled: userConfig.enableLocalAudio)
            }
    }
}

public extension View {
    func hoshiConfigEnvironment() -> some View {
        environment(HoshiConfig.config)
    }
    
    func observeLocalAudioToggleChange() -> some View {
        modifier(ObserveAudioToggleChangeModifier())
    }
}
