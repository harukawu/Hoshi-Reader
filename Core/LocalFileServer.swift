//
//  LocalFileServer.swift
//  Hoshi Reader
//
//  Copyright © 2026 Manhhao.
//  SPDX-License-Identifier: GPL-3.0-or-later
//

import Foundation
import Network

@MainActor
class LocalFileServer {
    private var listener: NWListener?
    private var fileData: Data?
    private var mimeType = "application/octet-stream"
    
    func start(file: URL) throws {
        fileData = try Data(contentsOf: file)
        mimeType = switch file.pathExtension.lowercased() {
        case "jpg", "jpeg": "image/jpeg"
        case "png": "image/png"
        default: "application/octet-stream"
        }
        
        listener = try NWListener(using: .tcp, on: 8080)
        listener?.newConnectionHandler = { [weak self] connection in
            Task { @MainActor in
                self?.handle(connection)
            }
        }
        listener?.start(queue: .main)
    }
    
    func stop() {
        listener?.cancel()
        listener = nil
        fileData = nil
    }
    
    private func handle(_ connection: NWConnection) {
        connection.start(queue: .main)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 512) { [weak self] _, _, _, _ in
            Task { @MainActor in
                self?.respond(connection)
            }
        }
    }
    
    private func respond(_ connection: NWConnection) {
        guard let fileData = fileData else {
            connection.cancel()
            return
        }
        let header = """
            HTTP/1.1 200 OK\r
            Content-Type: \(mimeType)\r
            Content-Length: \(fileData.count)\r
            Connection: close\r
            \r\n
            """
        connection.send(content: Data(header.utf8) + fileData, completion: .contentProcessed { _ in connection.cancel() })
    }
}
