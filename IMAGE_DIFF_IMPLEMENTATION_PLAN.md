# Git Show Image Diff Implementation Plan

## Overview
Implement `git show` functionality for displaying images in a side-by-side comparison view, following the existing TCA (The Composable Architecture) patterns used in the Diffi codebase.

## Current Architecture Analysis

### Existing Components
- **Git Package**: Local package with libgit2 wrapper (`/Git/`)
  - `Repo.swift`: Git repository operations
  - `Diff.swift`: Diff operations and file change detection
  - `Git.swift`: Core Git functionality
- **GitService**: Dependency injection wrapper for Git operations
- **DiffFeature**: TCA reducer for polling file changes
- **FilePickerFeature**: TCA reducer for file selection
- **Spike Implementation**: `ImageDiffViewSpike.swift` - proof of concept

### Current Git Capabilities
- `diffNameStatus(from:to:)`: Compare two commits
- `diffNameStatusWorkingTree()`: Compare HEAD to working directory
- Uses libgit2 via `Clibgit2.xcframework`

## Implementation Plan

### Phase 1: Git Package Extensions

#### 1.1 Add Blob Operations to Git Package
**File**: `/Git/Sources/Git/Blob.swift` (new)
```swift
public extension Git {
    enum Blob {
        static func lookup(repo: OpaquePointer, oid: GitOID) throws(GitError) -> OpaquePointer
        static func data(_ blob: OpaquePointer) -> Data
        static func free(_ blob: OpaquePointer)
    }
}
```

#### 1.2 Add Tree Entry Operations
**File**: `/Git/Sources/Git/Tree.swift` (extend existing)
```swift
// Add to existing Tree extension:
static func entryByPath(tree: OpaquePointer, path: String) throws(GitError) -> OpaquePointer
static func entryOID(_ entry: OpaquePointer) -> GitOID
```

#### 1.3 Add Git Show Operation to Repo
**File**: `/Git/Sources/Git/Repo.swift` (extend)
```swift
// Add to Repo class:
public func show(revspec: String, filePath: String) throws(GitError) -> Data
```

### Phase 2: Service Layer Extensions

#### 2.1 Extend GitService
**File**: `/Sources/Diffi/GitService.swift`
```swift
struct GitService {
    var performDiff: (URL) -> Result<[PickableFile], GitError>
    var showFile: (URL, String, String) -> Result<Data, GitError> // NEW
}
```

### Phase 3: Feature Implementation

#### 3.1 Create ImageDiffFeature
**File**: `/Sources/Diffi/ImageDiffFeature.swift` (new)
```swift
@Reducer
public struct ImageDiffFeature {
    @ObservableState
    public struct State: Equatable {
        var repositoryPath: URL?
        var filePath: String?
        var fileStatus: Git.Diff.Status?
        var previousVersionData: Data?
        var currentVersionData: Data?
        var isLoading: Bool = false
        var error: GitError?
    }
    
    public enum Action: Equatable {
        case loadImages(repositoryPath: URL, filePath: String, fileStatus: Git.Diff.Status)
        case previousVersionLoaded(Result<Data, GitError>)
        case currentVersionLoaded(Result<Data, GitError>)
    }
    
    @Dependency(\.gitService) var gitService
    
    public var body: some ReducerOf<Self> {
        // Implementation
    }
}
```

#### 3.2 Create ImageDiffView
**File**: `/Sources/Diffi/ImageDiffView.swift` (new)
```swift
struct ImageDiffView: View {
    @Bindable var store: StoreOf<ImageDiffFeature>
    
    var body: some View {
        // Side-by-side image comparison UI
        // Based on ImageDiffViewSpike but using TCA
    }
}
```

### Phase 4: Integration

#### 4.1 File Type Detection
**Utility**: Add image file extension detection
```swift
extension String {
    var isImageFile: Bool {
        let imageExtensions = ["png", "jpg", "jpeg", "gif", "bmp", "tiff", "webp"]
        return imageExtensions.contains(self.pathExtension.lowercased())
    }
}
```

#### 4.2 Navigation Integration
**Options for integration**:
1. **Route-based**: Add to existing navigation system
2. **Modal**: Present as sheet/modal from file picker
3. **Inline**: Replace diff view when image file selected

### Phase 5: Error Handling & Edge Cases

#### 5.1 Error Scenarios
- File doesn't exist in specified commit
- Binary file that's not an image
- Corrupt image data
- Git repository errors
- Memory constraints for large images

#### 5.2 Edge Cases
- New files (no previous version)
- Deleted files (no current version)
- Renamed files
- Very large images
- Unsupported image formats

## Implementation Details

### Data Flow
1. User selects image file from FilePickerFeature
2. Check if file is image type
3. If image: navigate to ImageDiffFeature
4. ImageDiffFeature loads both versions asynchronously:
   - Current version: read from working directory
   - Previous version: `git show HEAD:path/to/file`
5. Display side-by-side comparison

### Performance Considerations
- Load images asynchronously to avoid blocking UI
- Consider image size limits
- Implement proper memory management
- Cache loaded image data if navigating back/forth

### Testing Strategy
- Unit tests for Git package extensions
- Unit tests for ImageDiffFeature reducer
- Integration tests with real git repositories
- UI tests for ImageDiffView
- Test with various image formats and file states

## Migration from Spike

### What to Keep from ImageDiffViewSpike
- Side-by-side layout concept
- Async image loading pattern
- Error state handling for missing images
- "New File" placeholder logic

### What to Replace
- Direct Process/shell script execution → use Git package
- Direct file I/O → use GitService dependency
- Manual state management → use TCA reducer
- Hardcoded temp file paths → proper Data handling

## Future Enhancements

### Phase 6: Advanced Features (Future)
- Image overlay/diff highlighting
- Zoom and pan capabilities
- Image metadata comparison
- Support for more file types
- Performance metrics and caching
- Keyboard shortcuts for navigation

### Phase 7: Configuration (Future)
- User preferences for image viewing
- Custom image viewers
- Export capabilities
- Image comparison algorithms

## Implementation Order

1. **Start with Git package extensions** - foundational layer
2. **Extend GitService** - dependency injection layer
3. **Create ImageDiffFeature** - business logic layer
4. **Create ImageDiffView** - presentation layer
5. **Add file type detection** - utility layer
6. **Integrate with navigation** - application layer
7. **Add comprehensive error handling** - robustness layer
8. **Testing and refinement** - quality assurance

## Success Criteria

- [ ] Can display side-by-side image comparison for modified files
- [ ] Gracefully handles new files (shows placeholder)
- [ ] Proper error handling for all edge cases
- [ ] Follows existing TCA patterns in codebase
- [ ] No performance degradation from image loading
- [ ] Clean separation of concerns between layers
- [ ] Comprehensive test coverage
- [ ] Documentation and code comments

## Dependencies

### External
- libgit2 (already available via Clibgit2.xcframework)
- SwiftUI (for UI)
- ComposableArchitecture (already in use)

### Internal
- Git package (extend existing)
- GitService (extend existing)
- Existing navigation/routing system (integrate with)

## Risk Mitigation

### Technical Risks
- **libgit2 API complexity**: Mitigate by following existing patterns in Git package
- **Memory usage with large images**: Implement size limits and async loading
- **Git repository edge cases**: Comprehensive error handling and testing

### Architectural Risks
- **Breaking existing patterns**: Follow established TCA patterns closely
- **Tight coupling**: Use dependency injection and clear interfaces
- **Performance impact**: Implement proper async handling and caching

## Notes

This plan builds upon the existing ImageDiffViewSpike proof of concept while properly integrating with the existing TCA architecture. The modular approach allows for incremental development and testing at each layer.