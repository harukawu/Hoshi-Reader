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
        .package(url: "https://github.com/Manhhao/hoshidicts.git", revision: "01630e8648153ef160c39d92ec2838e90a0168c4"),
        .package(url: "https://github.com/siteline/SwiftUI-Introspect", from: "26.0.0"),
        .package(name: "EPUBKit", path: "Libraries/EPUBKit")
    ],
    targets: [
        .target(
            name: "HoshiReader",
            dependencies: [
                .product(name: "CHoshiDicts", package: "hoshidicts"),
                .product(name: "EPUBKit", package: "EPUBKit"),
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
    swiftLanguageModes: [.v6]
)
