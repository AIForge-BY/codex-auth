import AppKit
import Foundation

enum CodexDirectoryPicker {
    @MainActor
    static func chooseDirectory(completion: @escaping @MainActor (String?) -> Void) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        Task.detached {
            let directoryPath = runChooseFolderScript()
            await MainActor.run {
                completion(directoryPath)
            }
        }
    }

    private static func runChooseFolderScript() -> String? {
        let script = """
        set chosenFolder to choose folder with prompt "选择 Codex 会话目录"
        POSIX path of chosenFolder
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else {
            return nil
        }

        let output = stdout.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: output, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let path, !path.isEmpty else {
            return nil
        }
        return path
    }
}
