//
//  Startup.swift
//  HoshiReader
//
//  Created by Haruka on 2026/8/30.
//

public func hoshiStartup() {
    _ = DictionaryManager.shared
    _ = GoogleDriveHandler.shared
    WebViewPreloader.shared.warmup()
}
