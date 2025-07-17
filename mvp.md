# Git Image Diff Tool - MVP Plan

## Overview
A simple macOS app that monitors git repositories for image file changes and provides a side-by-side diff view.

## Core Features (MVP)
- Directory picker to select a git repository
- List of changed image files
- Side-by-side view of before/after images
- Automatic refresh every 2 seconds

## Technical Stack
- **SwiftUI** for UI
- **The Composable Architecture (TCA)** for state management
- **Timer-based polling** for git monitoring (no FSEventStream complexity)
- **Process API** for git CLI commands

## Architecture

### TCA State
```swift
struct State {
    var repositoryPath: URL?
    var changedImageFiles: [String] = []
    var selectedFile: String?
    var showingFolderPicker = false
}
```

### TCA Actions
```swift
enum Action {
    case folderPickerButtonTapped
    case folderSelected(URL)
    case folderPickerDismissed
    case timerTicked
    case gitFilesLoaded([String])
    case fileSelected(String?)
}
```

### Dependencies
- `GitService` - Handles git CLI operations
- `ContinuousClock` - For timer effects

## Git Operations

### Get Changed Image Files
```bash
git diff --name-only --diff-filter=M
```
Filter results for image extensions: `.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`

### Get File Versions
- **Current version**: Read directly from file system
- **Previous version**: `git show HEAD:path/to/file`

## UI Structure

### Main View
- Split view with file list on left, diff view on right
- If no repository selected: show directory picker button
- If repository selected: show file list + diff view

### Directory Picker
- Use SwiftUI's `fileImporter` with `.folder` content type
- Validate selected directory contains `.git` folder
- Handle security-scoped resources properly

### File List
- Simple `List` showing changed image file paths
- Selection binding to show diff in detail view

### Image Diff View
- Two `AsyncImage` views side-by-side
- Load before/after images and display with proper scaling
- Handle cases where file doesn't exist in HEAD (new files)

## Implementation Steps

1. **Basic TCA Setup**
   - Create App, State, Actions, and Reducer
   - Set up basic SwiftUI view structure

2. **Directory Selection**
   - Implement folder picker with validation

3. **Git Service**
   - Create dependency with git CLI operations
   - Implement changed files detection
   - Implement file version retrieval

4. **Timer Integration**
   - Add timer effect that triggers git operations

5. **Image Loading**
   - Create ImageDiffView component
   - Handle Data -> NSImage -> Image conversion
