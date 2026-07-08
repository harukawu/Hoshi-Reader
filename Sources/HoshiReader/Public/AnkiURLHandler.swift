//
//  AnkiURLHandler.swift
//  HoshiReader
//
//  Created by Haruka on 2026/7/6.
//

import Foundation

public func handleAnkiURL(_ url: URL, scheme: String) {
    guard url.scheme == scheme else { return }
    if url.host == "ankiFetch" {
        AnkiManager.shared.fetch()
    } else if url.host == "ankiSuccess" {
        LocalFileServer.shared.clearMedia()
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let expression = components.queryItems?.first(where: { $0.name == "expression" })?.value {
            AnkiManager.shared.addWord(expression)
        }
    }
}
