import AppKit

struct PasteboardSnapshot {
    let itemData: [[NSPasteboard.PasteboardType: Data]]

    init(pasteboard: NSPasteboard) {
        self.itemData = pasteboard.pasteboardItems?.map { item in
            var dataByType: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    dataByType[type] = data
                }
            }
            return dataByType
        } ?? []
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard !itemData.isEmpty else { return }
        let items = itemData.map { entry -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in entry {
                item.setData(data, forType: type)
            }
            return item
        }
        pasteboard.writeObjects(items)
    }
}

class ClipboardManager {
    enum ClipboardError: LocalizedError {
        case noTextSelected
        case textReplacementFailed
        
        var errorDescription: String? {
            switch self {
            case .noTextSelected:
                return "No text selected"
            case .textReplacementFailed:
                return "Failed to replace selected text"
            }
        }
    }
    
    private let pasteboard = NSPasteboard.general
    private var previousSnapshot: PasteboardSnapshot?
    
    func getSelectedText() async throws -> String {
        log("Attempting to get selected text")
        
        // Save current clipboard content
        previousSnapshot = PasteboardSnapshot(pasteboard: pasteboard)
        log("Saved previous clipboard content")

        let initialChangeCount = pasteboard.changeCount
        
        // Simulate copy command
        let source = CGEventSource(stateID: .privateState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true) // 'c' key
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        
        log("Simulating CMD+C to capture selection")
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
        
        let updated = await waitForPasteboardChange(from: initialChangeCount, timeout: 0.5)
        if !updated {
            log("Pasteboard did not update after copy", type: .warning)
        }
        
        guard let selectedText = pasteboard.string(forType: .string) else {
            log("No text found in clipboard", type: .warning)
            // Restore previous clipboard content
            restorePreviousClipboard()
            throw ClipboardError.noTextSelected
        }
        
        log("Successfully captured text: \(selectedText.prefix(50))...")
        return selectedText
    }
    
    func replaceSelectedText(with newText: String) async throws {
        log("Attempting to replace text with new content (length: \(newText.count))")
        
        // Store new text in clipboard
        pasteboard.clearContents()
        pasteboard.setString(newText, forType: .string)
        log("New text stored in clipboard")
        
        // Simulate paste command
        let source = CGEventSource(stateID: .privateState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // 'v' key
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        
        log("Simulating CMD+V to paste improved text")
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
        
        // Wait a bit for the paste to complete
        try await Task.sleep(nanoseconds: 100_000_000)

        restorePreviousClipboard()
        
        log("Text replacement complete")
    }

    private func restorePreviousClipboard() {
        if let snapshot = previousSnapshot {
            snapshot.restore(to: pasteboard)
            previousSnapshot = nil
            log("Restored previous clipboard content")
        }
    }

    private func waitForPasteboardChange(from initialChangeCount: Int, timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if pasteboard.changeCount != initialChangeCount {
                return true
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        return false
    }
}
