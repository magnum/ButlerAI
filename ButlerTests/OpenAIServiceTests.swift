import XCTest
@testable import Butler

final class OpenAIClientTests: XCTestCase {
    func testOpenAIEndpointWithV1BaseURL() {
        let baseURL = URL(string: "https://api.openai.com/v1")!
        let endpoint = OpenAIClient.chatEndpoint(for: .openAI, baseURL: baseURL)
        XCTAssertEqual(endpoint.absoluteString, "https://api.openai.com/v1/chat/completions")
    }

    func testOpenAIEndpointWithBareBaseURL() {
        let baseURL = URL(string: "https://api.openai.com")!
        let endpoint = OpenAIClient.chatEndpoint(for: .openAI, baseURL: baseURL)
        XCTAssertEqual(endpoint.absoluteString, "https://api.openai.com/v1/chat/completions")
    }

    func testOpenAIEndpointWithCustomBaseURL() {
        let baseURL = URL(string: "http://localhost:1234")!
        let endpoint = OpenAIClient.chatEndpoint(for: .openAI, baseURL: baseURL)
        XCTAssertEqual(endpoint.absoluteString, "http://localhost:1234/v1/chat/completions")
    }

    func testOllamaEndpoint() {
        let baseURL = URL(string: "http://localhost:11434")!
        let endpoint = OpenAIClient.chatEndpoint(for: .ollama, baseURL: baseURL)
        XCTAssertEqual(endpoint.absoluteString, "http://localhost:11434/api/chat")
    }
}
