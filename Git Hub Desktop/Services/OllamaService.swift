import Foundation
import AppKit

enum OllamaError: Error, LocalizedError {
    case notRunning
    case notInstalled
    case generationFailed(String)
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .notRunning:
            return "Ollama is not running. Please start the Ollama application."
        case .notInstalled:
            return "Ollama does not appear to be installed in /usr/local/bin."
        case .generationFailed(let msg):
            return "Failed to generate AI response: \(msg)"
        case .invalidResponse:
            return "Invalid response from Ollama."
        }
    }
}

nonisolated class OllamaService {
    
    private let baseURL = URL(string: "http://localhost:11434/api/generate")!
    private let modelName = "qwen3:8b" // Default model
    private var process: Process?
    
    init() {
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { _ in
            self.process?.terminate()
        }
    }
    
    deinit {
        process?.terminate()
    }
    
    func isOllamaRunning() async -> Bool {
        guard let url = URL(string: "http://localhost:11434/") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 2.0
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                return true
            }
        } catch {
            return false
        }
        return false
    }
    
    func startOllamaProcess() throws {

        let ollamaPath = "/opt/homebrew/bin/ollama"
        guard FileManager.default.fileExists(atPath: ollamaPath) else {
            throw OllamaError.notInstalled
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ollamaPath)
        process.arguments = ["serve"]
        
        // Output pipes can be ignored or logged
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        
        do {
            try process.run()
            self.process = process
            // We do not wait until exit because it's a server process
        } catch {
            throw OllamaError.generationFailed("Could not start Ollama process: \(error.localizedDescription)")
        }
    }
    
    func generateCommitMessage(diff: String) async throws -> String {
        guard await isOllamaRunning() else {
            throw OllamaError.notRunning
        }
        
        let prompt = """
        You are an expert developer. Please generate a concise, conventional commit message based on the following git diff.
        Do not include any greetings, explanations, or conversational text. Output ONLY the commit message.
        If there are multiple logical changes, use a short summary line, followed by a blank line, followed by bullet points.
        
        Diff:
        \(diff)
        """
        
        return try await generate(prompt: prompt)
    }
    
    func generateSuggestions(diff: String) async throws -> String {
        guard await isOllamaRunning() else {
            throw OllamaError.notRunning
        }
        
        let prompt = """
        You are an expert code reviewer. Review the following git diff and provide concise suggestions for improvement.
        Focus on potential bugs, performance issues, readability, and best practices.
        If the code looks good, simply reply with "The changes look solid. No major suggestions."
        
        Diff:
        \(diff)
        """
        
        return try await generate(prompt: prompt)
    }
    
    private func generate(prompt: String) async throws -> String {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": modelName,
            "prompt": prompt,
            "stream": false
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw OllamaError.generationFailed("Failed to encode request body.")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            if let errorMessage = json?["error"] as? String {
                throw OllamaError.generationFailed("Ollama Error: \(errorMessage)")
            }
            throw OllamaError.invalidResponse
        }
        
        guard let validJson = json, let generatedText = validJson["response"] as? String else {
            throw OllamaError.invalidResponse
        }
        
        return generatedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
