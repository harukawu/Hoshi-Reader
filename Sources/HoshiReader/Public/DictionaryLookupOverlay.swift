//
//  DictionaryLookupOverlay.swift
//  Hoshi Reader
//
//  Copyright © 2026 Manhhao.
//  SPDX-License-Identifier: GPL-3.0-or-later
//

import SwiftUI
import CHoshiDicts

public struct DictionaryLookupOverlay: View {
    @Environment(UserConfig.self) private var userConfig

    @State private var popups: [PopupItem] = []
    @State private var didPerformInitialLookup = false
    @State private var isDismissing = false

    private let query: String
    private let sentence: String
    private let selectionRect: CGRect
    private let mediaProvider: (@concurrent () async throws -> (imageURL: URL, audioURL: URL, videoTitle: String, sentence: String?)?)?
    private let miningHistorySaver: (((sentence: String, clozeOffset: Int?, title: String, imageExtension: String, formatID: UUID, imageData: Data, audioData: Data, content: [String : String])) -> Void)?
    private let onMatchedUTF16Length: (Int) -> Void
    private let onDismiss: () -> Void

    public init(
        query: String,
        sentence: String,
        selectionRect: CGRect,
        mediaProvider: (@concurrent () async throws -> (imageURL: URL, audioURL: URL, videoTitle: String, sentence: String?)?)?,
        miningHistorySaver: (((sentence: String, clozeOffset: Int?, title: String, imageExtension: String, formatID: UUID, imageData: Data, audioData: Data, content: [String : String])) -> Void)? = nil,
        onMatchedUTF16Length: @escaping (Int) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.query = query
        self.sentence = sentence
        self.selectionRect = selectionRect
        self.mediaProvider = mediaProvider
        self.miningHistorySaver = miningHistorySaver
        self.onMatchedUTF16Length = onMatchedUTF16Length
        self.onDismiss = onDismiss
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                if !popups.isEmpty {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture(perform: closePopups)
                }

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
        .onAppear(perform: performInitialLookup)
    }

    private func performInitialLookup() {
        guard !didPerformInitialLookup else { return }
        didPerformInitialLookup = true

        let selection = SelectionData(
            text: query,
            sentence: sentence,
            rect: selectionRect,
            normalizedOffset: nil
        )

        guard let matchedUTF16Length = showPopup(for: selection) else {
            onDismiss()
            return
        }

        onMatchedUTF16Length(matchedUTF16Length)
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

        var dictionaryStyles: [String: String] = [:]
        for style in LookupEngine.shared.getStyles() {
            dictionaryStyles[String(style.dict_name)] = String(style.styles)
        }

        let popup = PopupItem(
            showPopup: false,
            currentSelection: selection,
            lookupResults: lookupResults,
            dictionaryStyles: dictionaryStyles,
            isVertical: false,
            isFullWidth: false,
            clearSelection: false,
            sasayakiCue: nil
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

        return String(firstResult.matched).utf16.count
    }

    private func dismissPopup(id: UUID) {
        guard let index = popups.firstIndex(where: { $0.id == id }) else {
            return
        }

        if index == 0 {
            closePopups()
        } else if popups.indices.contains(index - 1) {
            popups[index - 1].clearSelection.toggle()
            closeChildPopups(parent: index - 1)
        }
    }

    private func closePopups() {
        guard !popups.isEmpty, !isDismissing else { return }
        isDismissing = true

        let popupIDs = Set(popups.map(\.id))
        withAnimation(.default.speed(2.4)) {
            popups = popups.map {
                var popup = $0
                popup.showPopup = false
                return popup
            }
        } completion: {
            popups.removeAll { popupIDs.contains($0.id) }
            isDismissing = false
            onDismiss()
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
}
