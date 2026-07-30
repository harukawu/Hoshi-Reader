//
//  HoshiAnkiManager.swift
//  HoshiReader
//
//  Created by Haruka on 2026/7/26.
//

import Foundation

@available(anyAppleOS 26, *)
final public class AnkiSuccessMessage: NotificationCenter.AsyncMessage {
    public typealias Subject = HoshiAnkiManager
}

@available(anyAppleOS 26, *)
public extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<AnkiSuccessMessage> {
    static var ankiAddNoteSuccess: Self { .init() }
}

@Observable
public class HoshiAnkiManager {

    public static let shared = HoshiAnkiManager()

    private init() {}

    public func addNote(from history: (
        sentence: String,
        clozeOffset: Int?,
        title: String,
        imageExtension: String,
        formatID: UUID,
        imageURL: URL,
        audioData: Data,
        content: [String : String]
    )) async -> Bool {
        await AnkiManager.shared.addNote(
            content: history.content,
            context: MiningContext(
                sentence: history.sentence,
                clozeOffset: history.clozeOffset,
                documentTitle: history.title,
                coverURL: history.imageURL,
                sasayakiAudioData: history.audioData
            ),
            formatId: history.formatID
        )
    }
}
