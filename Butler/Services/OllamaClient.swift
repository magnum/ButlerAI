import Foundation

final class OllamaClient: TextImproving {
    private let basePrompt: String
    private let model: String
    private let baseURL: URL

    init(prompt: String, model: String, serverURL: String) {
        self.basePrompt = prompt
        self.model = model
        self.baseURL = URL(string: serverURL) ?? URL(string: "http://localhost:11434")!
        log("Ollama client initialized with model: \(model), BaseURL: \(self.baseURL.absoluteString)")
    }

    static func fetchModels(serverURL: String = "http://localhost:11434") async throws -> [String] {
        let url = URL(string: "\(serverURL)/api/tags")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        log("Fetching models from Ollama server: \(serverURL)")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                log("Invalid response from Ollama server (not an HTTPURLResponse)", type: .error)
                throw OpenAIError.invalidResponse(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, responseBody: "Response was not HTTPURLResponse")
            }

            if httpResponse.statusCode != 200 {
                let responseBody = String(data: data, encoding: .utf8)
                log("HTTP \(httpResponse.statusCode) from Ollama server. Body: \(responseBody ?? "nil")", type: .error)
                throw OpenAIError.invalidResponse(statusCode: httpResponse.statusCode, responseBody: responseBody)
            }

            let modelResponse = try JSONDecoder().decode(OllamaModelsResponse.self, from: data)
            log("Successfully fetched \(modelResponse.models.count) models from Ollama")
            return modelResponse.models.map { $0.name }
        } catch let error as DecodingError {
            log("Failed to decode Ollama models response: \(error.localizedDescription)", type: .error)
            throw OpenAIError.responseDecodingError(underlyingError: error)
        } catch let error as OpenAIError {
            throw error
        } catch {
            log("Failed to fetch Ollama models: \(error.localizedDescription)", type: .error)
            throw OpenAIError.networkError(underlyingError: error)
        }
    }

    func improveText(_ text: String) async throws -> String {
        log("Starting Ollama text improvement request")

        let endpoint = OpenAIClient.chatEndpoint(for: .ollama, baseURL: baseURL)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "model": model,
            "messages": [
                [
                    "role": "system",
                    "content": basePrompt
                ],
                [
                    "role": "user",
                    "content": text
                ]
            ],
            "stream": false,
            "options": [
                "temperature": 0.7
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            log("Ollama request payload prepared")

            let (data, response) = try await URLSession.shared.data(for: request)
            log("Received response from Ollama service")

            guard let httpResponse = response as? HTTPURLResponse else {
                log("Error: Invalid response type from Ollama server", type: .error)
                throw OpenAIError.invalidResponse(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, responseBody: "Response was not HTTPURLResponse")
            }

            if httpResponse.statusCode != 200 {
                let responseBody = String(data: data, encoding: .utf8)
                log("HTTP Error: \(httpResponse.statusCode). Body: \(responseBody ?? "nil")", type: .error)
                throw OpenAIError.invalidResponse(statusCode: httpResponse.statusCode, responseBody: responseBody)
            }

            log("Parsing Ollama response")
            let apiResponse = try JSONDecoder().decode(OllamaChatResponse.self, from: data)

            let finalContent = apiResponse.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            log("Successfully extracted improved text (length: \(finalContent.count))")
            return finalContent
        } catch let error as DecodingError {
            log("Error decoding Ollama response: \(error.localizedDescription)", type: .error)
            throw OpenAIError.responseDecodingError(underlyingError: error)
        } catch let error as OpenAIError {
            throw error
        } catch {
            log("Error during Ollama request: \(error.localizedDescription)", type: .error)
            throw OpenAIError.networkError(underlyingError: error)
        }
    }
}

struct OllamaChatResponse: Codable {
    struct Message: Codable {
        let role: String
        let content: String
    }

    let message: Message
}

struct OllamaModelsResponse: Codable {
    struct Model: Codable {
        let name: String
    }

    let models: [Model]
}
