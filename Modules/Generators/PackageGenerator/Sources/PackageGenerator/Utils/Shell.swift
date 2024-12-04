import ArgumentParser
import Foundation

struct Shell {
    var verbose: Bool = false

    @discardableResult
    func execute(_ command: String) throws -> String {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.standardOutput = pipe
        process.standardError = pipe

        if verbose {
            Task {
                await Console.print(.computer, command)
            }
        }

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            if verbose {
                output.split(separator: "\n").forEach { line in
                    Task {
                        await Console.print(level: 1, .none, String(line))
                    }
                }
            }
            return output
        } else {
            throw ExitCode.failure
        }
    }
    
    @discardableResult
    func executeScript(at path: String) throws -> String {
        // Read the script from the file at the specified path
        guard let scriptContent = try? String(contentsOfFile: path, encoding: .utf8) else {
            throw NSError(domain: "Shell", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to read file at \(path)"])
        }
        
        // Execute the script content
        return try execute(scriptContent)
    }    
}
