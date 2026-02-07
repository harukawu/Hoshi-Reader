//
//  Dictionary.swift
//  Hoshi Reader
//
//  Copyright © 2026 Manhhao.
//  SPDX-License-Identifier: GPL-3.0-or-later
//

import Foundation

struct DictionaryInfo: Identifiable, Codable {
    let id: UUID
    let name: String
    let path: URL
    var isEnabled: Bool
    var order: Int
    
    init(id: UUID = UUID(), name: String, path: URL, isEnabled: Bool = true, order: Int = 0) {
        self.id = id
        self.name = name
        self.path = path
        self.isEnabled = isEnabled
        self.order = order
    }
}

struct DictionaryConfig: Codable {
    var termDictionaries: [DictionaryEntry]
    var frequencyDictionaries: [DictionaryEntry]
    var pitchDictionaries: [DictionaryEntry]
    var customCSS: String
    
    init(termDictionaries: [DictionaryEntry], frequencyDictionaries: [DictionaryEntry], pitchDictionaries: [DictionaryEntry], customCSS: String) {
        self.termDictionaries = termDictionaries
        self.frequencyDictionaries = frequencyDictionaries
        self.pitchDictionaries = pitchDictionaries
        self.customCSS = customCSS
    }
    
    struct DictionaryEntry: Codable {
        let fileName: String
        var isEnabled: Bool
        var order: Int
    }
    
    enum CodingKeys: String, CodingKey {
        case termDictionaries
        case frequencyDictionaries
        case pitchDictionaries
        case customCSS
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.termDictionaries = try container.decode([DictionaryEntry].self, forKey: .termDictionaries)
        self.frequencyDictionaries = try container.decode([DictionaryEntry].self, forKey: .frequencyDictionaries)
        self.pitchDictionaries = try container.decode([DictionaryEntry].self, forKey: .pitchDictionaries)
        self.customCSS = try container.decodeIfPresent(String.self, forKey: .customCSS) ?? ""
    }
}

struct GlossaryData: Encodable {
    let dictionary: String
    let content: String
    let definitionTags: String
    let termTags: String
}

struct FrequencyData: Encodable {
    let dictionary: String
    let frequencies: [FrequencyTag]
}

struct PitchData: Encodable {
    let dictionary: String
    let pitchPositions: [Int]
}

struct EntryData: Encodable {
    let expression: String
    let reading: String
    let matched: String
    let deinflectionTrace: [DeinflectionTag]
    let glossaries: [GlossaryData]
    let frequencies: [FrequencyData]
    let pitches: [PitchData]
    let definitionTags: [String]
}

struct DeinflectionTag: Encodable {
    let name: String
    let description: String
}

struct FrequencyTag: Encodable {
    let value: Int
    let displayValue: String
}

struct AudioSource: Codable, Identifiable {
    var id: String { url }
    let url: String
    var isEnabled: Bool
    let isDefault: Bool

    init(url: String, isEnabled: Bool = true, isDefault: Bool = false) {
        self.url = url
        self.isEnabled = isEnabled
        self.isDefault = isDefault
    }
}
