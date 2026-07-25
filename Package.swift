// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "HoshiReader",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(name: "HoshiReader", targets: ["HoshiReader"])
    ],
    dependencies: [
        .package(url: "https://github.com/Manhhao/hoshidicts.git", branch: "main"),
        .package(url: "https://github.com/hidden-spectrum/SwiftLAME.git", branch: "main"),
        .package(url: "https://github.com/tadija/AEXML", from: "4.7.0"),
        .package(url: "https://github.com/siteline/SwiftUI-Introspect", from: "26.0.0"),
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.20")
    ],
    targets: [
        .target(
            name: "EPUBKit",
            dependencies: [
                .product(name: "AEXML", package: "aexml"),
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ],
            path: "Libraries/EPUBKit/Sources/EPUBKit"
        ),
        .target(
            name: "HoshiReader",
            dependencies: [
                .product(name: "CHoshiDicts", package: "hoshidicts"),
                .product(name: "SwiftLAME", package: "SwiftLAME"),
                "EPUBKit",
                .product(name: "SwiftUIIntrospect", package: "swiftui-introspect")
            ],
            resources: [
                .process("Resources"),
                .process("Features/Popup/popup.css"),
                .process("Features/Popup/popup.js"),
                .process("Features/Reader/Highlights/highlights.js"),
                .process("Features/Reader/ReaderWebView/reader.js"),
                .process("Features/Reader/ReaderWebView/selection.js"),
                .process("Features/Reader/ScrollReaderWebView/scrollreader.js"),
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx),
                .defaultIsolation(MainActor.self)
            ]
        )
    ],
    swiftLanguageModes: [.v6],
    cxxLanguageStandard: .cxx2b
)
