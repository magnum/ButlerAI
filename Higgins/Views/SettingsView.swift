import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsService
    @State private var availableModels: [String] = []
    @State private var isLoadingModels: Bool = false
    @State private var errorMessage: String = ""
    @State private var showingAddPromptModal: Bool = false
    @State private var confirmDeletePrompt: Bool = false
    @State private var newPromptName: String = ""
    @State private var showingRenamePromptModal: Bool = false
    @State private var renamePromptName: String = ""

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("AI Backend", selection: $settings.aiBackend) {
                        ForEach(AIBackendType.allCases) { backendType in
                            Text(backendType.displayName).tag(backendType)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: settings.aiBackend) { _, newValue in
                        if newValue == .ollama {
                            Task {
                                await fetchOllamaModels()
                            }
                        } else {
                            // Reset to default OpenAI model when switching back
                            settings.selectedModel = AIModelConstants.defaultOpenAIModel
                        }
                    }

                    if settings.aiBackend == .openAI {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("OpenAI API Key")
                                .font(.headline)
                            SecureField("Enter your API key", text: $settings.openaiKey)
                                .textFieldStyle(.roundedBorder)

                            Text("OpenAI Base URL")
                                .font(.headline)
                            TextField("https://api.openai.com/v1", text: $settings.openAIBaseURL)
                                .textFieldStyle(.roundedBorder)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Ollama Server URL")
                                .font(.headline)
                            TextField("Server URL", text: $settings.ollamaURL)
                                .textFieldStyle(.roundedBorder)
                            
                            Text("Model")
                                .font(.headline)
                            if isLoadingModels {
                                ProgressView("Loading models...")
                            } else {
                                Picker("Model", selection: $settings.selectedModel) {
                                    ForEach(availableModels, id: \.self) { model in
                                        Text(model).tag(model)
                                    }
                                }
                                .disabled(availableModels.isEmpty)
                                
                                if !errorMessage.isEmpty {
                                    Text(errorMessage)
                                        .foregroundColor(.red)
                                        .font(.caption)
                                }
                                
                                Button("Refresh Models") {
                                    Task {
                                        await fetchOllamaModels()
                                    }
                                }
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .center, spacing: 8) {
                            Text("Prompts")
                                .font(.headline)

                            Picker("", selection: Binding(
                                get: { settings.currentPromptIndex },
                                set: { newIndex in settings.selectPrompt(at: newIndex) }
                            )) {
                                ForEach(Array(settings.promptNames.enumerated()), id: \.offset) { index, name in
                                    Text(name.isEmpty ? (index == 0 ? "default" : "prompt \(index)") : name).tag(index)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity)

                            HStack(spacing: 8) {
                                Button {
                                    renamePromptName = settings.promptNames.indices.contains(settings.currentPromptIndex) ? settings.promptNames[settings.currentPromptIndex] : ""
                                    showingRenamePromptModal = true
                                } label: {
                                    Image(systemName: "pencil")
                                        .frame(width: 24, height: 24)
                                }
                                .buttonStyle(.bordered)
                                .help("Rename selected prompt")

                                Button {
                                    showingAddPromptModal = true
                                } label: {
                                    Image(systemName: "plus")
                                        .frame(width: 24, height: 24)
                                }
                                .buttonStyle(.bordered)
                                .help("Add new prompt")

                                Button {
                                    confirmDeletePrompt = true
                                } label: {
                                    Image(systemName: "minus")
                                        .frame(width: 24, height: 24)
                                }
                                .buttonStyle(.bordered)
                                .help("Delete selected prompt")
                                .disabled(settings.prompts.count <= 1)
                            }
                        }

                        TextEditor(text: Binding(
                            get: { settings.improvementPrompt },
                            set: { newValue in
                                if settings.prompts.indices.contains(settings.currentPromptIndex) {
                                    settings.prompts[settings.currentPromptIndex] = newValue
                                }
                            }
                        ))
                        .font(.body)
                        .frame(minHeight: 140)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
            }
            .padding()
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Keyboard Shortcut")
                        .font(.headline)
                    HStack(spacing: 4) {
                        Text("⌃⌥⌘C")
                            .padding(4)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                        Text("- Improve Selected Text")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
        }
        .frame(width: 400)
        .sheet(isPresented: $showingAddPromptModal) {
            let trimmedName = newPromptName.trimmingCharacters(in: .whitespacesAndNewlines)
            let duplicate = settings.promptNames.contains(where: { $0.caseInsensitiveCompare(trimmedName) == .orderedSame })
            let empty = trimmedName.isEmpty
            
            VStack(alignment: .leading, spacing: 12) {
                Text("New Prompt")
                    .font(.headline)
                TextField("Prompt name", text: $newPromptName)
                    .textFieldStyle(.roundedBorder)
                if empty {
                    Text("Name cannot be empty")
                        .foregroundColor(.red)
                        .font(.caption)
                } else if duplicate {
                    Text("A prompt with this name already exists")
                        .foregroundColor(.red)
                        .font(.caption)
                }
                HStack {
                    Spacer()
                    Button("Cancel") {
                        showingAddPromptModal = false
                        newPromptName = ""
                    }
                    Button("OK") {
                        let content = settings.improvementPrompt
                        settings.addPrompt(named: trimmedName.isEmpty ? "untitled" : trimmedName, withContent: content)
                        showingAddPromptModal = false
                        newPromptName = ""
                    }
                    .disabled(empty || duplicate)
                }
            }
            .padding()
            .frame(width: 360)
        }
        .sheet(isPresented: $showingRenamePromptModal) {
            let trimmedName = renamePromptName.trimmingCharacters(in: .whitespacesAndNewlines)
            let duplicate = settings.promptNames.contains(where: { $0.caseInsensitiveCompare(trimmedName) == .orderedSame }) && (settings.promptNames.indices.contains(settings.currentPromptIndex) ? settings.promptNames[settings.currentPromptIndex].caseInsensitiveCompare(trimmedName) != .orderedSame : true)
            let empty = trimmedName.isEmpty

            VStack(alignment: .leading, spacing: 12) {
                Text("Rename Prompt")
                    .font(.headline)
                TextField("Prompt name", text: $renamePromptName)
                    .textFieldStyle(.roundedBorder)
                if empty {
                    Text("Name cannot be empty")
                        .foregroundColor(.red)
                        .font(.caption)
                } else if duplicate {
                    Text("A prompt with this name already exists")
                        .foregroundColor(.red)
                        .font(.caption)
                }
                HStack {
                    Spacer()
                    Button("Cancel") {
                        showingRenamePromptModal = false
                        renamePromptName = ""
                    }
                    Button("OK") {
                        settings.renameCurrentPrompt(to: trimmedName)
                        showingRenamePromptModal = false
                        renamePromptName = ""
                    }
                    .disabled(empty || duplicate)
                }
            }
            .padding()
            .frame(width: 360)
        }
        .alert("Delete selected prompt?", isPresented: $confirmDeletePrompt) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                settings.removeCurrentPrompt()
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }
    
    private func fetchOllamaModels() async {
        isLoadingModels = true
        errorMessage = ""
        
        do {
            availableModels = try await OllamaClient.fetchModels(serverURL: settings.ollamaURL)
            if !availableModels.isEmpty && !availableModels.contains(settings.selectedModel) {
                settings.selectedModel = availableModels[0]
            }
        } catch {
            errorMessage = error.localizedDescription
            availableModels = []
        }
        
        isLoadingModels = false
    }
}
