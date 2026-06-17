//
//  DiffModel.swift
//  Git Hub Desktop
//

import Foundation

enum DiffLineType: Equatable {
    case added
    case removed
    case context
    case hunkHeader
    case fileHeader
}

struct DiffLine: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let type: DiffLineType
    let oldLineNumber: Int?
    let newLineNumber: Int?
}

struct FileDiff: Equatable {
    let lines: [DiffLine]
    let isNewFile: Bool
    let isDeletedFile: Bool
}
