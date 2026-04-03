import SwiftUI

struct RefinementSettingsSection: View {
    @Environment(DictationController.self) private var controller

    @AppStorage("ollama.enabled") private var ollamaEnabled: Bool = true
    @AppStorage("ollama.model") private var ollamaModel: String = "mistral"
    @AppStorage("ollama.customPrompt") private var customPrompt: String = ""
    @AppStorage("ollama.temperature") private var temperature: Double = 0.3

    @State private var availableOllamaModels: [String] = []

    var body: some View {
        Section("AI Refinement") {
            Toggle("Enable AI polish", isOn: $ollamaEnabled)

            if ollamaEnabled {
                ollamaStatusRow
                modelPicker
                refreshButton
                installHint
                advancedSettings
            }
        }
    }

    private var ollamaStatusRow: some View {
        HStack {
            Text("Ollama")
            Spacer()
            if controller.ollamaAvailable {
                Label("Connected", systemImage: "circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            } else {
                Label("Not running", systemImage: "circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
    }

    private var modelPicker: some View {
        Picker("Model", selection: $ollamaModel) {
            if availableOllamaModels.isEmpty {
                Text(ollamaModel).tag(ollamaModel)
            } else {
                ForEach(availableOllamaModels, id: \.self) { model in
                    Text(model).tag(model)
                }
            }
        }
        .task {
            await refreshOllamaModels()
        }
    }

    private var refreshButton: some View {
        Button("Refresh Models", action: refreshModels)
            .buttonStyle(.borderless)
            .font(.caption)
    }

    @ViewBuilder
    private var installHint: some View {
        if !controller.ollamaAvailable {
            Text("Install Ollama from ollama.com and run: ollama pull \(ollamaModel)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var advancedSettings: some View {
        DisclosureGroup("Advanced") {
            VStack(alignment: .leading) {
                Text("System Prompt")
                    .font(.caption)
                TextField("Custom system prompt", text: $customPrompt, axis: .vertical)
                    .lineLimit(3...)
                    .font(.caption)
                if customPrompt.isEmpty {
                    Text("Using default prompt")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            HStack {
                Text("Temperature")
                Slider(value: $temperature, in: 0...1, step: 0.1)
                Text(String(format: "%.1f", temperature))
                    .monospacedDigit()
                    .font(.caption)
            }
        }
    }

    private func refreshModels() {
        Task { await refreshOllamaModels() }
    }

    private func refreshOllamaModels() async {
        let client = OllamaClient()
        do {
            availableOllamaModels = try await client.listModels()
        } catch {
            availableOllamaModels = []
        }
    }
}
