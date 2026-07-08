//
//  HoshiWarmup.swift
//  HoshiReader
//
//  Created by Haruka on 2026/7/9.
//

public func hoshiWarmup() {
    WebViewPreloader.shared.warmup()
    _ = DictionaryManager.shared
}
