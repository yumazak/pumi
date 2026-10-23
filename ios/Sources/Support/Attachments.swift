import Foundation
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Turns a picked photo or file into an opencode `FileAttachment`: a `data:`
/// URI, so the bridge never has to read the device's file system.
enum Attachment {
    static func photo(_ item: PhotosPickerItem) async throws -> PromptFile {
        guard let data = try await item.loadTransferable(type: Data.self) else {
            throw AttachmentError.unreadable
        }
        let jpeg = UIImage(data: data)?
            .preparingThumbnail(of: CGSize(width: 1600, height: 1600))?
            .jpegData(compressionQuality: 0.8) ?? data
        return PromptFile(
            uri: "data:image/jpeg;base64,\(jpeg.base64EncodedString())",
            name: "photo-\(Int(Date().timeIntervalSince1970)).jpg"
        )
    }

    static func file(_ url: URL) throws -> PromptFile {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        guard data.count <= 10 * 1024 * 1024 else { throw AttachmentError.tooLarge }
        let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType
            ?? "application/octet-stream"
        return PromptFile(
            uri: "data:\(mime);base64,\(data.base64EncodedString())",
            name: url.lastPathComponent
        )
    }
}

enum AttachmentError: LocalizedError {
    case unreadable
    case tooLarge

    var errorDescription: String? {
        switch self {
        case .unreadable: return "添付を読み込めませんでした"
        case .tooLarge: return "ファイルが大きすぎます（上限 10MB）"
        }
    }
}
