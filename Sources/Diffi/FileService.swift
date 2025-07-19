//
//  FileService.swift
//  Diffi
//
//  Created by Shawn Gee on 7/17/25.
//

import ComposableArchitecture
import Foundation

struct FileService {
    var fileExists: (_ atPath: String, _ isDirectory: UnsafeMutablePointer<ObjCBool>) -> Bool
}

extension FileService: DependencyKey {
    static var liveValue: Self {
        return Self(fileExists: FileManager.default.fileExists)
    }
}

extension DependencyValues {
    var fileService: FileService {
        get { self[FileService.self] }
        set { self[FileService.self] = newValue }
    }
}
