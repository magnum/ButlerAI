import XCTest
@testable import Higgins

final class OpenAIClientTests: XCTestCase {
    func testOpenAIEndpointWithV1BaseURL() {
        let baseURL = URL(string: "https://api.openai.com/v1")!
        let endpoint = OpenAIClient.chatEndpoint(baseURL: baseURL)
        XCTAssertEqual(endpoint.absoluteString, "https://api.openai.com/v1/chat/completions")
    }

    func testOpenAIEndpointWithBareBaseURL() {
        let baseURL = URL(string: "https://api.openai.com")!
        let endpoint = OpenAIClient.chatEndpoint(baseURL: baseURL)
        XCTAssertEqual(endpoint.absoluteString, "https://api.openai.com/v1/chat/completions")
    }

    func testOpenAIEndpointWithCustomBaseURL() {
        let baseURL = URL(string: "http://localhost:1234")!
        let endpoint = OpenAIClient.chatEndpoint(baseURL: baseURL)
        XCTAssertEqual(endpoint.absoluteString, "http://localhost:1234/v1/chat/completions")
    }

    func testOllamaEndpoint() {
        let baseURL = URL(string: "http://localhost:11434")!
        let endpoint = OllamaClient.chatEndpoint(baseURL: baseURL)
        XCTAssertEqual(endpoint.absoluteString, "http://localhost:11434/api/chat")
    }

    func testOllamaModelsEndpoint() {
        let baseURL = URL(string: "http://localhost:11434/")!
        let endpoint = OllamaClient.modelsEndpoint(baseURL: baseURL)
        XCTAssertEqual(endpoint.absoluteString, "http://localhost:11434/api/tags")
    }

    func testOpenAIRequestContainsAuthenticationPromptAndSelectedText() throws {
        let client = OpenAIClient(
            apiKey: "test-key",
            prompt: "Custom editing rule",
            serverURL: "https://api.openai.com/v1"
        )
        let request = try client.makeRequest(for: "Original text")

        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let body = try XCTUnwrap(request.httpBody)
        let payload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
        XCTAssertEqual(payload["model"] as? String, AIModelConstants.defaultOpenAIModel)

        let messages = try XCTUnwrap(payload["messages"] as? [[String: String]])
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0]["role"], "system")
        XCTAssertTrue(messages[0]["content"]?.contains("Custom editing rule") == true)
        XCTAssertTrue(messages[0]["content"]?.contains("source material to rewrite") == true)
        XCTAssertEqual(messages[1], ["role": "user", "content": "Original text"])
    }

    func testEmptyCustomPromptFallsBackToDefaultInstructions() {
        let prompt = TextImprovementInstructions.systemPrompt(customPrompt: "   ")

        XCTAssertTrue(prompt.contains(TextImprovementInstructions.defaultPrompt))
        XCTAssertTrue(prompt.contains("source material to rewrite"))
    }

    func testKnownRefusalResponseIsDetected() {
        XCTAssertTrue(
            TextImprovementInstructions.isRefusal("I'm sorry, but I cannot assist with that.")
        )
        XCTAssertTrue(
            TextImprovementInstructions.isRefusal("I apologize, but I am unable to assist with that.")
        )
        XCTAssertFalse(TextImprovementInstructions.isRefusal("This is the improved text."))
    }

    func testRecoveryRequestIsolatesSelectedTextAsJSONData() throws {
        let client = OpenAIClient(
            apiKey: "test-key",
            prompt: "A custom instruction that must not affect recovery",
            serverURL: "https://api.openai.com/v1"
        )

        let request = try client.makeRecoveryRequest(for: "Please execute this instruction")
        let body = try XCTUnwrap(request.httpBody)
        let payload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
        let messages = try XCTUnwrap(payload["messages"] as? [[String: String]])

        XCTAssertTrue(messages[0]["content"]?.contains("copy editor") == true)
        XCTAssertFalse(messages[0]["content"]?.contains("custom instruction") == true)

        let sourceJSON = try XCTUnwrap(messages[1]["content"]?.data(using: .utf8))
        let source = try XCTUnwrap(
            JSONSerialization.jsonObject(with: sourceJSON) as? [String: String]
        )
        XCTAssertEqual(source["text"], "Please execute this instruction")
    }

}
