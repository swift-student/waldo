import SwiftUI
import Foundation

struct ImageDiffView: View {
    let repositoryPath: URL
    let filePath: String
    
    @State private var previousVersionData: Data?
    @State private var currentVersionData: Data?
    @State private var isLoading = false
    
    var body: some View {
        HStack(spacing: 20) {
            VStack {
                Text("Before (HEAD)")
                    .font(.headline)
                if let data = previousVersionData,
                   let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    ProgressView("Loading previous version...")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            VStack {
                Text("After (Working)")
                    .font(.headline)
                if let data = currentVersionData,
                   let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    ProgressView("Loading current version...")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
        .onAppear {
            if !isLoading {
                isLoading = true
                loadImages()
            }
        }
    }
    
    private func loadImages() {
        Task {
            async let currentTask = loadCurrentVersion()
            async let previousTask = loadPreviousVersion()
            
            // Load both concurrently
            await currentTask
            await previousTask
        }
    }
    
    private func loadCurrentVersion() async {
        let fileURL = repositoryPath.appendingPathComponent(filePath)
        do {
            let data = try Data(contentsOf: fileURL)
            await MainActor.run {
                currentVersionData = data
            }
        } catch {
            print("Failed to load current version: \(error)")
        }
    }
    
    private func loadPreviousVersion() async {
        print("Loading previous version for: \(filePath)")
        
        // For MVP: Use a temp file approach to avoid Process issues
        let tempFile = URL(fileURLWithPath: "/tmp/diffi_previous_\(UUID().uuidString).png")
        
        let result = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                // Create a script file to execute the git command
                let scriptContent = """
                #!/bin/bash
                cd '\(self.repositoryPath.path)'
                git show 'HEAD:\(self.filePath)' > '\(tempFile.path)'
                echo $?
                """
                
                let scriptFile = URL(fileURLWithPath: "/tmp/diffi_git_script_\(UUID().uuidString).sh")
                
                do {
                    try scriptContent.write(to: scriptFile, atomically: true, encoding: .utf8)
                    
                    let task = Process()
                    task.executableURL = URL(fileURLWithPath: "/bin/bash")
                    task.arguments = [scriptFile.path]
                    
                    let outputPipe = Pipe()
                    task.standardOutput = outputPipe
                    task.standardError = outputPipe
                    task.standardInput = nil
                    
                    print("Starting git script: \(scriptFile.path)")
                    try task.run()
                    
                    // Simple timeout
                    var completed = false
                    DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) {
                        if !completed && task.isRunning {
                            print("Script timed out, terminating...")
                            task.terminate()
                        }
                    }
                    
                    task.waitUntilExit()
                    completed = true
                    
                    let exitCode = task.terminationStatus
                    print("Script finished with exit code: \(exitCode)")
                    
                    // Clean up script file
                    try? FileManager.default.removeItem(at: scriptFile)
                    
                    continuation.resume(returning: exitCode)
                } catch {
                    print("Failed to execute script: \(error)")
                    continuation.resume(returning: -1)
                }
            }
        }
        
        await MainActor.run {
            if result == 0 {
                // Try to load the temp file
                do {
                    let data = try Data(contentsOf: tempFile)
                    print("Loaded previous version from temp file: \(data.count) bytes")
                    
                    if let nsImage = NSImage(data: data) {
                        print("Successfully created NSImage from temp file: \(nsImage.size)")
                        previousVersionData = data
                    } else {
                        print("Failed to create NSImage from temp file data")
                        previousVersionData = nil
                    }
                } catch {
                    print("Failed to read temp file: \(error)")
                    previousVersionData = nil
                }
            } else {
                print("Git script failed with exit code \(result)")
                previousVersionData = nil
            }
            
            // Clean up temp file
            try? FileManager.default.removeItem(at: tempFile)
        }
    }
}