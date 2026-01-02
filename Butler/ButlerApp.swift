import SwiftUI
import AppKit
import Combine

@MainActor
class AppState: ObservableObject {
    private var hotkeyManager: HotkeyManager?
    private let clipboardManager = ClipboardManager()
    private var textImprover: TextImproving?
    private var languageService: LanguageService?
    @Published var isProcessing: Bool = false
    
    let settingsService = SettingsService()
    private var cancellables = Set<AnyCancellable>()
    var openSettingsHandler: (() -> Void)?
    
    @Published var lastError: String? {
        didSet {
            if let error = self.lastError {
                log(error, type: .error)
            }
        }
    }
    
    init() {
        log("Initializing ButlerAI")
        self.updateAIService() // Initial call
        if RuntimeEnvironment.isRunningTests {
            log("Skipping hotkey setup during tests")
        } else {
            self.setupHotkeyManager()
        }
        
        settingsService.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    log("SettingsService changed, updating AI Service.")
                    self?.updateAIService()
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateAIService() {
        let client: TextImproving
        switch settingsService.aiBackend {
        case .openAI:
            client = OpenAIClient(
                apiKey: settingsService.openaiKey,
                prompt: settingsService.improvementPrompt,
                model: settingsService.selectedModel,
                serverURL: settingsService.openAIBaseURL
            )
        case .ollama:
            client = OllamaClient(
                prompt: settingsService.improvementPrompt,
                model: settingsService.selectedModel,
                serverURL: settingsService.ollamaURL
            )
        }

        textImprover = client
        languageService = LanguageService(textImprover: client)
        log("AI service updated (Backend: \(settingsService.aiBackend.rawValue), Model: \(settingsService.selectedModel))")
    }
    
    private func setupHotkeyManager() {
        log("Setting up hotkey (⌃⌥⌘C)")
        hotkeyManager = HotkeyManager { [weak self] in
            log("Hotkey triggered")
            Task { [weak self] in
                await self?.improveSelectedText()
            }
        }
    }
    
    private func improveSelectedText() async {
        log("Starting text improvement")
        do {
            isProcessing = true
            let selectedText = try await clipboardManager.getSelectedText()
            log("Selected text: \(selectedText.prefix(50))...")
            
            guard let improved = try await languageService?.improveWithLanguageHandling(selectedText) else {
                let errorMessage = settingsService.aiBackend == .openAI ?
                    "OpenAI API key not configured." :
                    "Ollama connection failed. Ensure Ollama is running and the URL is correct in settings."
                lastError = errorMessage
                let alert = NSAlert()
                alert.messageText = settingsService.aiBackend == .openAI ?
                    "OpenAI API Key Required" :
                    "Ollama Connection Error"
                alert.informativeText = settingsService.aiBackend == .openAI ?
                    "Please open Settings and enter your OpenAI API key to use ButlerAI." :
                    "Please make sure Ollama is running and check your server URL in Settings."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Open Settings")
                alert.addButton(withTitle: "Cancel")
                
                NSApp.activate(ignoringOtherApps: true)
                if alert.runModal() == .alertFirstButtonReturn {
                    if let openSettingsHandler {
                        openSettingsHandler()
                    } else {
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    }
                }
                isProcessing = false
                return
            }
            log("Received improved text from AI service")
            
            try await clipboardManager.replaceSelectedText(with: improved)
            log("Successfully replaced text")
            lastError = nil
            isProcessing = false
        } catch let error as OpenAIError {
            isProcessing = false
            log("AI service error: \(error.localizedDescription)", type: .error)
            lastError = error.localizedDescription
            let alert = NSAlert()
            alert.messageText = "\(settingsService.aiBackend.displayName) Error" // Using displayName from enum
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        } catch let error as ClipboardManager.ClipboardError {
            isProcessing = false
            log("Clipboard error: \(error.localizedDescription)", type: .error)
            lastError = error.localizedDescription
            let alert = NSAlert()
            alert.messageText = "No Text Selected"
            alert.informativeText = "Please select some text to improve."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        } catch {
            log("Unexpected error: \(error)", type: .error)
            lastError = "An unexpected error occurred"
            isProcessing = false
        }
    }
}

@main
struct ButlerApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        MenuBarExtra {
            MenuContentView(appState: appState)
        } label: {
            if appState.isProcessing {
                Image(systemName: "clock.arrow.circlepath")
                    .imageScale(.medium)
                    .rotationEffect(.degrees(appState.isProcessing ? 360 : 0))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: appState.isProcessing)
            } else {
                Image(systemName: "wand.and.stars")
            }
        }

        Settings {
            SettingsView(settings: appState.settingsService)
        }

        Window("ButlerAI Logs", id: "logs") {
            LogView()
        }
        .defaultSize(width: 800, height: 600)
    }
}

struct MenuContentView: View {
    @ObservedObject var appState: AppState
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Group {
                    if appState.isProcessing {
                        Image(systemName: "clock.arrow.circlepath")
                            .imageScale(.medium)
                            .rotationEffect(.degrees(appState.isProcessing ? 360 : 0))
                            .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: appState.isProcessing)
                    } else {
                        Image(systemName: "wand.and.stars")
                    }
                }
                .frame(width: 18, height: 18)

                Text("ButlerAI")
                    .font(.headline)
            }
            .padding(.vertical, 8)

            Divider()

            if let error = appState.lastError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.subheadline)
                    .lineLimit(3)
                    .padding(.vertical, 8)
                    .padding(.horizontal)

                Divider()
            }

            Button("Show Logs") {
                log("Opening logs from menu")
                openWindow(id: "logs")
            }
            .keyboardShortcut("l")
            .padding(.vertical, 4)

            Button("Settings...") {
                log("Opening settings from menu")
                openSettings()
            }
            .keyboardShortcut(",")
            .padding(.vertical, 4)

            Button("Quit ButlerAI") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
            .padding(.vertical, 4)
        }
        .fixedSize()
        .onAppear {
            appState.openSettingsHandler = {
                openSettings()
            }
        }
    }
}
