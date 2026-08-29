//
//  HoshiConfig.swift
//  Hoshi Reader
//
//  Copyright © 2026 Manhhao.
//  SPDX-License-Identifier: GPL-3.0-or-later
//

import SwiftUI

private struct HoshiConfigModifier: ViewModifier {
    static let config = UserConfig()
    
    func body(content: Content) -> some View {
        content
            .environment(Self.config)
    }
}

public extension View {
    func hoshiConfigEnvironment() -> some View {
        modifier(HoshiConfigModifier())
    }
}
