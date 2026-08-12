import Foundation
import NaturalLanguage
import SwiftUI

class LanguageService: ObservableObject {
    private let textImprover: TextImproving
    
    init(textImprover: TextImproving) {
        self.textImprover = textImprover
    }
    
    func improveWithLanguageHandling(_ text: String) async throws -> String {
        return try await textImprover.improveText(text)
    }
}
