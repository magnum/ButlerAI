//
//  HigginsTests.swift
//  HigginsTests
//
//  Created by Scalzo, Giordano on 04/03/2025.
//

import XCTest
@testable import Higgins
#if canImport(AppIntents)
import AppIntents
#endif

final class HigginsTests: XCTestCase {
    func testDetectLanguageItalian() {
        let service = LanguageService(textImprover: OpenAIClient(
            apiKey: "test-key",
            prompt: "test-prompt",
            model: AIModelConstants.defaultOpenAIModel,
            serverURL: ""
        ))
        let detected = service.detectLanguage(text: "Questo è un test.")
        XCTAssertEqual(detected, "it")
    }

    func testDetectLanguageNonItalianReturnsNil() {
        let service = LanguageService(textImprover: OpenAIClient(
            apiKey: "test-key",
            prompt: "test-prompt",
            model: AIModelConstants.defaultOpenAIModel,
            serverURL: ""
        ))
        let detected = service.detectLanguage(text: "This is a test.")
        XCTAssertNil(detected)
    }
}
