//
//  DictionarySearchPanel.swift
//  Hoshi Reader
//
//  Copyright © 2026 Manhhao.
//  SPDX-License-Identifier: GPL-3.0-or-later
//

import SwiftUI
import CHoshiDicts

public struct DictionarySearchPanel: View {
    @Environment(UserConfig.self) private var userConfig

    @State private var content = ""
    @State private var dictionaryStyles: [String: String] = [:]
    @State private var lookupEntries: [[String: Any]] = []
    @State private var searchedQuery = ""
    @State private var webViewID = UUID()
    @State private var hasPerformedLookup = false
    @State private var popups: [PopupItem] = []
    @State private var clearSelection = false
    @State private var backCount = 0
    @State private var forwardCount = 0
    @State private var backTrigger = false
    @State private var forwardTrigger = false

    private let query: String
    private let mediaProvider: (@concurrent () async throws -> (imageURL: URL, audioURL: URL, videoTitle: String, sentence: String?)?)?
    private let miningHistorySaver: (((sentence: String, clozeOffset: Int?, title: String, imageExtension: String, formatID: UUID, imageData: Data, audioData: Data, content: [String : String])) -> Void)?

    public init(
        query: String,
        mediaProvider: (@concurrent () async throws -> (imageURL: URL, audioURL: URL, videoTitle: String, sentence: String?)?)?,
        miningHistorySaver: (((sentence: String, clozeOffset: Int?, title: String, imageExtension: String, formatID: UUID, imageData: Data, audioData: Data, content: [String : String])) -> Void)? = nil
    ) {
        self.query = query
        self.mediaProvider = mediaProvider
        self.miningHistorySaver = miningHistorySaver
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                results

                ForEach($popups) { $popup in
                    let popupID = popup.id

                    PopupView(
                        userConfig: userConfig,
                        isVisible: $popup.showPopup,
                        selectionData: popup.currentSelection,
                        lookupResults: popup.lookupResults,
                        dictionaryStyles: popup.dictionaryStyles,
                        screenSize: geometry.size,
                        isVertical: popup.isVertical,
                        isFullWidth: popup.isFullWidth,
                        coverURL: nil,
                        documentTitle: nil,
                        clearSelection: popup.clearSelection,
                        mediaProvider: mediaProvider,
                        miningHistorySaver: miningHistorySaver,
                        onTextSelected: { selection in
                            if let index = popups.firstIndex(where: { $0.id == popupID }) {
                                closeChildPopups(parent: index)
                            }
                            return showPopup(for: selection)
                        },
                        onTapOutside: {
                            if let index = popups.firstIndex(where: { $0.id == popupID }) {
                                closeChildPopups(parent: index)
                            }
                        },
                        onSwipeDismiss: {
                            dismissPopup(id: popupID)
                        }
                    )
                    .zIndex(Double(100 + (popups.firstIndex(where: { $0.id == popupID }) ?? 0)))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .onAppear(perform: runLookup)
        .onChange(of: query, runLookup)
    }

    @ViewBuilder
    private var results: some View {
        if hasPerformedLookup, lookupEntries.isEmpty {
            ContentUnavailableView(
                "No Dictionary Results",
                systemImage: "character.book.closed",
                description: Text(searchedQuery)
            )
        } else {
            PopupWebView(
                content: content,
                position: .zero,
                scale: CGFloat(userConfig.popupScale),
                clearSelection: clearSelection,
                dictionaryStyles: dictionaryStyles,
                lookupEntries: lookupEntries,
                scanNonJapaneseText: userConfig.scanNonJapaneseText,
                scanLength: userConfig.scanLength,
                backTrigger: backTrigger,
                forwardTrigger: forwardTrigger,
                onMine: { minedContent, formatId in
                    if let mediaProvider {
                        if let media = try? await mediaProvider(),
                           let audioData = try? Data(contentsOf: media.audioURL, options: .mappedIfSafe) {
                            if let miningHistorySaver, !AnkiManager.shared.useAnkiConnect {
                                if let imageData = try? Data(contentsOf: media.imageURL, options: .mappedIfSafe) {
                                    miningHistorySaver((
                                        sentence: media.sentence ?? "",
                                        clozeOffset: nil,
                                        title: media.videoTitle,
                                        imageExtension: media.imageURL.pathExtension,
                                        formatID: formatId,
                                        imageData: imageData,
                                        audioData: audioData,
                                        content: minedContent
                                    ))
                                }
                            } else {
                                return await AnkiManager.shared.addNote(
                                    content: minedContent,
                                    context: MiningContext(
                                        sentence: media.sentence ?? "",
                                        clozeOffset: nil,
                                        documentTitle: media.videoTitle,
                                        coverURL: media.imageURL,
                                        sasayakiAudioData: audioData
                                    ),
                                    formatId: formatId
                                )
                            }
                        }
                        return false
                    }
                    
                    return await AnkiManager.shared.addNote(
                        content: minedContent,
                        context: MiningContext(
                            sentence: searchedQuery,
                            documentTitle: nil,
                            coverURL: nil
                        ),
                        formatId: formatId
                    )
                },
                onTextSelected: { selection in
                    closePopups()
                    return showPopup(for: selection)
                },
                onTapOutside: closePopups,
                onRedirect: { redirectedQuery in
                    closePopups()

                    let results = LookupEngine.shared.lookup(
                        redirectedQuery,
                        maxResults: userConfig.maxResults,
                        scanLength: userConfig.scanLength
                    )
                    let entries = Self.buildLookupEntries(lookupResults: results)

                    if !entries.isEmpty {
                        backCount += 1
                        forwardCount = 0
                    }

                    return entries
                },
                onKanjiRedirect: { kanji in
                    let data = LookupEngine.shared.queryKanji(kanji)
                    if data != nil {
                        backCount += 1
                        forwardCount = 0
                    }
                    return data
                },
                scrollViewBounces: true
            )
            .id(webViewID)
            .simultaneousGesture(historyGesture)
        }
    }

    private var historyGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height

                guard abs(dx) > abs(dy), abs(dy) < 20 else {
                    return
                }

                if dx > 0 {
                    guard backCount > 0 else { return }
                    backTrigger.toggle()
                    backCount -= 1
                    forwardCount += 1
                } else {
                    guard forwardCount > 0 else { return }
                    forwardTrigger.toggle()
                    forwardCount -= 1
                    backCount += 1
                }
            }
    }

    private func runLookup() {
        closePopups()
        backCount = 0
        forwardCount = 0

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        searchedQuery = trimmedQuery
        hasPerformedLookup = true

        guard !trimmedQuery.isEmpty else {
            clearResults()
            return
        }

        let results = LookupEngine.shared.lookup(
            trimmedQuery,
            maxResults: userConfig.maxResults,
            scanLength: userConfig.scanLength
        )

        guard !results.isEmpty else {
            clearResults()
            return
        }

        dictionaryStyles = makeDictionaryStyles()
        lookupEntries = Self.buildLookupEntries(lookupResults: results)
        content = makeContent()
        webViewID = UUID()
    }

    private func clearResults() {
        content = ""
        dictionaryStyles = [:]
        lookupEntries = []
        webViewID = UUID()
    }

    private func showPopup(for selection: SelectionData) -> Int? {
        let lookupResults = LookupEngine.shared.lookup(
            selection.text,
            maxResults: userConfig.maxResults,
            scanLength: userConfig.scanLength
        )

        guard let firstResult = lookupResults.first else {
            return nil
        }

        let popup = PopupItem(
            showPopup: false,
            currentSelection: selection,
            lookupResults: lookupResults,
            dictionaryStyles: makeDictionaryStyles(),
            isVertical: false,
            isFullWidth: false,
            clearSelection: false
        )
        popups.append(popup)

        withAnimation(.default.speed(2.2)) {
            popups = popups.map {
                var item = $0
                if item.id == popup.id {
                    item.showPopup = true
                }
                return item
            }
        }

        return String(firstResult.matched).count
    }

    private func makeDictionaryStyles() -> [String: String] {
        var styles: [String: String] = [:]

        for style in LookupEngine.shared.getStyles() {
            styles[String(style.dict_name)] = String(style.styles)
        }

        return styles
    }

    private func dismissPopup(id: UUID) {
        guard let index = popups.firstIndex(where: { $0.id == id }) else {
            return
        }

        if index == 0 {
            clearSelection.toggle()
            closePopups()
        } else if popups.indices.contains(index - 1) {
            popups[index - 1].clearSelection.toggle()
            closeChildPopups(parent: index - 1)
        }
    }

    private func closePopups() {
        let popupIDs = Set(popups.map(\.id))
        guard !popupIDs.isEmpty else { return }

        withAnimation(.default.speed(2.4)) {
            popups = popups.map {
                var popup = $0
                popup.showPopup = false
                return popup
            }
        } completion: {
            popups.removeAll { popupIDs.contains($0.id) }
        }
    }

    private func closeChildPopups(parent: Int) {
        let popupIDs = Set(popups.dropFirst(parent + 1).map(\.id))
        guard !popupIDs.isEmpty else { return }

        withAnimation(.default.speed(2.4)) {
            popups = popups.map {
                var popup = $0
                if popupIDs.contains(popup.id) {
                    popup.showPopup = false
                }
                return popup
            }
        } completion: {
            popups.removeAll { popupIDs.contains($0.id) }
        }
    }

    private func makeContent() -> String {
        let collapsedDictionaries = userConfig.collapseMode == .custom
            ? ((try? JSONEncoder().encode(DictionaryManager.shared.collapsedDictionaries))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "[]")
            : "[]"
        let audioSources = (try? JSONEncoder().encode(userConfig.enabledAudioSources))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        let excludedDictionaries = (try? JSONEncoder().encode(DictionaryManager.shared.excludedDictionaries))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        let scaledCSS = userConfig.customCSS.replacingOccurrences(
            of: #"(-?(?:\d+(?:\.\d+)?|\.\d+))px"#,
            with: "calc($1px * var(--popup-scale))",
            options: .regularExpression
        )
        let customCSS = (try? JSONSerialization.data(
            withJSONObject: scaledCSS,
            options: .fragmentsAllowed
        ))
        .flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""

        return """
        <style>
            body {
                padding: calc(12px * var(--popup-scale)) calc(16px * var(--popup-scale));
            }
        </style>
        <script>
            window.collapseMode = "\(userConfig.collapseMode.rawValue)";
            window.expandFirstDictionary = \(userConfig.expandFirstDictionary);
            window.collapsedDictionaries = \(collapsedDictionaries);
            window.twoColumnLayout = \(userConfig.twoColumnLayout);
            window.compactGlossaries = \(userConfig.compactGlossaries);
            window.showExpressionTags = \(userConfig.showExpressionTags);
            window.harmonicFrequency = \(userConfig.harmonicFrequency);
            window.deduplicatePitchAccents = \(userConfig.deduplicatePitchAccents);
            window.compactPitchAccents = \(userConfig.compactPitchAccents);
            window.audioSources = \(audioSources);
            window.audioEnableAutoplay = \(userConfig.audioEnableAutoplay);
            window.audioPlaybackMode = "\(userConfig.audioPlaybackMode.rawValue)";
            window.needsAudio = \(AnkiManager.shared.needsAudio);
            window.cardFormatCount = \(AnkiManager.shared.cardFormats.count);
            window.validFormatFlags = \(AnkiManager.shared.validFormatFlags);
            window.isAnkiConnectReachable = \(AnkiManager.shared.isAnkiConnectReachable);
            window.excludedDictionaries = \(excludedDictionaries);
            window.allowDupes = \(AnkiManager.shared.allowDupes);
            window.disableShowNotes = \(AnkiManager.shared.disableShowNotes);
            window.useAnkiConnect = \(AnkiManager.shared.useAnkiConnect);
            window.embedMedia = \(AnkiManager.shared.embedMedia);
            window.compactGlossariesAnki = \(AnkiManager.shared.compactGlossaries);
            window.customCSS = \(customCSS);
        </script>
        <div id="entries-container"></div>
        """
    }

    private static func buildLookupEntries(
        lookupResults: [LookupResult]
    ) -> [[String: Any]] {
        lookupResults.map { result in
            let deinflectionTrace = result.trace.reversed().map {
                [
                    "name": String($0.name),
                    "description": String($0.description),
                ]
            }
            let glossaries = result.term.glossaries.map {
                [
                    "dictionary": String($0.dict_name),
                    "content": String($0.glossary),
                    "definitionTags": String($0.definition_tags),
                    "termTags": String($0.term_tags),
                ]
            }
            let frequencies = result.term.frequencies.map { frequency in
                [
                    "dictionary": String(frequency.dict_name),
                    "frequencies": frequency.frequencies.map {
                        [
                            "value": Int($0.value),
                            "displayValue": String($0.display_value),
                        ]
                    },
                ] as [String: Any]
            }
            let pitches = result.term.pitches.map { pitch in
                var accents: [[String: Any]] = []
                var seen: Set<String> = []
                var transcriptions: [String] = []

                for element in pitch.pitches {
                    let pattern = String(element.pattern)
                    guard seen.insert(pattern.isEmpty ? String(element.position) : pattern).inserted else { continue }
                    let nasal = element.nasal.map { Int($0) }
                    let devoice = element.devoice.map { Int($0) }
                    let position: Any = pattern.isEmpty ? Int(element.position) : pattern
                    accents.append([
                        "position": position,
                        "nasal": nasal,
                        "devoice": devoice,
                    ])
                }

                for value in pitch.transcriptions {
                    let transcription = String(value)
                    if !transcriptions.contains(transcription) {
                        transcriptions.append(transcription)
                    }
                }

                return [
                    "dictionary": String(pitch.dict_name),
                    "pitches": accents,
                    "transcriptions": transcriptions,
                ] as [String: Any]
            }

            return [
                "expression": String(result.term.expression),
                "reading": String(result.term.reading),
                "matched": String(result.matched),
                "deinflectionTrace": deinflectionTrace,
                "glossaries": glossaries,
                "frequencies": frequencies,
                "pitches": pitches,
                "rules": String(result.term.rules).split(separator: " ").map(String.init),
            ]
        }
    }
}
