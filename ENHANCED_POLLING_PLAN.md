# Enhanced Polling Plan: Auto-Update ImageDiffView on File Changes

## Problem
Currently, the ImageDiffView only updates when a different file is selected, but doesn't update when the same file's content changes on disk. This means users don't see updated diffs when they modify an image file that's already selected.

## Solution: Option 2 - Enhanced Polling with File Modification Detection

This approach enhances the existing diff polling mechanism to detect when the currently selected image file has been modified and automatically triggers a reload.

## Current Architecture Overview

```
DiffFeature (polls every 5s) 
    ↓ 
GitService.performDiff() 
    ↓ 
AppFeature.diffResult() 
    ↓ 
FilePickerFeature (updates file list)
    ↓
ImageDiffFeature (observes selectedFile via SharedReader)
```

## Required Changes

### 1. **PickableFile.swift** - Add modification time tracking

**Location**: `/Sources/Diffi/PickableFile.swift:4`

**Change**: Add modification date property to track file timestamps
```swift
public struct PickableFile: Hashable, Equatable, Identifiable {
    public let id: String
    public let path: String
    public let status: Git.Diff.Status
    public let modificationDate: Date? // NEW: Track file modification time
    
    // Update initializers to include modificationDate
    public init(path: String, status: Git.Diff.Status, modificationDate: Date? = nil) {
        self.path = path
        self.status = status
        self.modificationDate = modificationDate
        id = path
    }
    
    public init(from fileChange: Git.Diff.FileChange, modificationDate: Date? = nil) {
        path = fileChange.path
        status = fileChange.status
        self.modificationDate = modificationDate
        id = fileChange.id
    }
}
```

### 2. **GitService.swift** - Enhance diff collection to include file timestamps

**Location**: `/Sources/Diffi/GitService.swift:13-22`

**Change**: Add file system timestamp lookup during diff collection
```swift
performDiff: { repoFolder in
    do throws(GitError) {
        let repo = try Git.Repo(url: repoFolder)
        let pickableFiles = try repo.status().map { fileChange in
            // NEW: Get file modification date for working tree files
            let modDate = getFileModificationDate(repoFolder: repoFolder, filePath: fileChange.path)
            return PickableFile(from: fileChange, modificationDate: modDate)
        }
        return .success(pickableFiles)
    } catch {
        print("GitService error: \(error)")
        return .failure(error)
    }
}

// NEW: Helper function to get file modification date
private func getFileModificationDate(repoFolder: URL, filePath: String) -> Date? {
    let fileURL = repoFolder.appendingPathComponent(filePath)
    do {
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        return attributes[.modificationDate] as? Date
    } catch {
        return nil
    }
}
```

### 3. **AppFeature.swift** - Enhanced diff result processing

**Location**: `/Sources/Diffi/AppFeature.swift:86-96`

**Change**: Add modification time comparison and trigger image reload
```swift
case let .diffFeature(.diffResult(.success(files))):
    let imageFiles = files.filter { $0.isImageFile }
    
    // NEW: Check if selected file's modification time changed
    if let selectedFile = state.selectedFile,
       let updatedFile = imageFiles.first(where: { $0.path == selectedFile.path }),
       let selectedModDate = selectedFile.modificationDate,
       let updatedModDate = updatedFile.modificationDate,
       updatedModDate > selectedModDate {
        
        // Update the selected file with new modification time
        state.$selectedFile.withLock { $0 = updatedFile }
        
        // Force ImageDiffFeature to reload by triggering selectedFileChanged
        return .merge(
            .send(.imageDiffFeature(.selectedFileChanged(
                repoFolder: state.repoFolder, 
                selectedFile: updatedFile
            ))),
            .none // Continue with normal processing
        )
    }
    
    // Check if selected file is still in the diff results
    if let selectedFile = state.selectedFile,
       !imageFiles.contains(where: { $0.path == selectedFile.path }) {
        state.$selectedFile.withLock { $0 = nil }
    }
    
    state.filePickerFeature.files = imageFiles
    return .none
```

### 4. **ImageDiffFeature.swift** - Make selectedFileChanged action public

**Location**: `/Sources/Diffi/ImageDiffFeature.swift:51-59`

**Change**: Ensure the action is accessible from AppFeature
```swift
public enum Action: Equatable {
    case onAppear
    case selectedFileChanged(repoFolder: URL?, selectedFile: PickableFile?) // Ensure this is public
    case startImageLoading(ImageVersionType)
    case imageLoaded(ImageVersionType, Result<LoadedImage, GitError>)
    case cancelLoading
    case setViewMode(ImageDiffViewMode)
    case setOpacityBlend(Double)
}
```

### 5. **AppFeature.swift** - Handle ImageDiffFeature actions

**Location**: `/Sources/Diffi/AppFeature.swift:101-102`

**Change**: Ensure ImageDiffFeature actions are properly routed (already exists)
```swift
case .imageDiffFeature:
    return .none // No change needed - already handles all ImageDiffFeature actions
```

## Enhanced Data Flow

```
DiffFeature (polls every 5s)
    ↓ 
GitService.performDiff() + file timestamps
    ↓ 
AppFeature.diffResult() + modification time comparison
    ↓ (if file changed)
ImageDiffFeature.selectedFileChanged() → reloads images
    ↓
ImageDiffView automatically updates (via existing SharedReader)
```

## Implementation Benefits

1. **Reuses existing architecture**: No changes needed to ImageDiffView or the image loading mechanism
2. **Minimal performance impact**: File timestamp checking is very fast
3. **Automatic updates**: Users see changes immediately when they save a file
4. **Robust**: Works with any file modification (external editors, git operations, etc.)

## Files That Need Changes

1. `Sources/Diffi/PickableFile.swift` - Add modificationDate property
2. `Sources/Diffi/GitService.swift` - Add file timestamp collection
3. `Sources/Diffi/AppFeature.swift` - Add modification time comparison logic
4. `Sources/Diffi/ImageDiffFeature.swift` - Ensure action accessibility

## Files That DON'T Need Changes

- `Sources/Diffi/ImageDiffView.swift` - Will automatically update via existing SharedReader
- `Sources/Diffi/DiffFeature.swift` - Polling mechanism remains unchanged
- `Sources/Diffi/FilePickerFeature.swift` - File list updates remain unchanged

## Testing Strategy

1. **Unit tests**: Verify modification date comparison logic in AppFeature
2. **Integration tests**: Test that file changes trigger image reloads
3. **Manual testing**: Modify an image file externally and verify the diff updates