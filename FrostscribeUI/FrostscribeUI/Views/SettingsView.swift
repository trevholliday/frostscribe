import SwiftUI
import FrostscribeCore

struct SettingsView: View {
    @State private var config      = Config()
    @State private var savedConfig = Config()
    @State private var saveError: String?
    @State private var savedConfirmation = false
    @State private var showAutoScribeConfirm = false

    private let configManager = ConfigManager()

    var body: some View {
        Form {
            Section("Paths") {
                textRow("Movies directory",  hint: "/Volumes/Media/Movies",       value: $config.moviesDir,    saved: savedConfig.moviesDir)
                textRow("TV Shows directory",hint: "/Volumes/Media/TV Shows",     value: $config.tvDir,        saved: savedConfig.tvDir)
                textRow("Temp directory",    hint: "/Volumes/Media/Ripping/queue",value: $config.tempDir,      saved: savedConfig.tempDir)
            }

            Section("Media") {
                Picker("Media server", selection: $config.mediaServer) {
                    ForEach(MediaServer.allCases, id: \.self) { server in
                        Text(server.rawValue.capitalized).tag(server)
                    }
                }
                .onChange(of: config.mediaServer) { save() }
            }

            Section("Tools & API Keys") {
                textRow("makemkvcon path",   hint: "/Applications/MakeMKV.app/Contents/MacOS/makemkvcon", value: $config.makemkvBin,  saved: savedConfig.makemkvBin)
                textRow("HandBrakeCLI path", hint: "/opt/homebrew/bin/HandBrakeCLI",                      value: $config.handbrakeBin, saved: savedConfig.handbrakeBin)
                secureRow("MakeMKV key",  hint: "optional", value: $config.makemkvKey,  saved: savedConfig.makemkvKey)
                secureRow("TMDB API key", hint: "optional", value: $config.tmdbApiKey,  saved: savedConfig.tmdbApiKey)
            }

            Section("Options") {
                Toggle("Enable notifications", isOn: $config.notificationsEnabled)
                    .tint(FrostTheme.frostCyan)
                    .onChange(of: config.notificationsEnabled) { save() }
                vigilModeToggle
                Toggle("Select audio tracks before ripping", isOn: $config.selectAudioTracks)
                    .tint(FrostTheme.frostCyan)
                    .onChange(of: config.selectAudioTracks) { save() }
            }

            if let error = saveError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(FrostTheme.alert)
                        .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .overlay(alignment: .bottom) {
            if savedConfirmation {
                Label("Saved", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(FrostTheme.teal)
                    .padding(.horizontal, FrostTheme.paddingM)
                    .padding(.vertical, FrostTheme.paddingS)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: FrostTheme.cornerRadius))
                    .padding(.bottom, FrostTheme.paddingM)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: savedConfirmation)
        .onAppear(perform: loadConfig)
    }

    // MARK: - Vigil / AutoScribe toggle

    private var vigilModeToggle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Vigil Mode", isOn: Binding(
                get: { config.vigilMode },
                set: { newValue in
                    if !newValue {
                        // Turning off Vigil = enabling AutoScribe — requires confirmation
                        showAutoScribeConfirm = true
                    } else {
                        config.vigilMode = true
                        save()
                    }
                }
            ))
            .tint(FrostTheme.frostCyan)
            Text(config.vigilMode
                 ? "You are present — ripping is guided and interactive."
                 : "AutoScribe active — discs are ripped automatically without prompting.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .confirmationDialog(
            "Enable AutoScribe?",
            isPresented: $showAutoScribeConfirm,
            titleVisibility: .visible
        ) {
            Button("Enable AutoScribe", role: .destructive) {
                config.vigilMode = false
                save()
            }
            Button("Keep Vigil Mode", role: .cancel) { }
        } message: {
            Text("AutoScribe will automatically rip any disc inserted into the drive without asking you first. Make sure you only insert discs you own.")
        }
    }

    // MARK: - Row helpers

    private func textRow(_ label: String, hint: String,
                         value: Binding<String>, saved: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(hint, text: value)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.leading)
            saveButtonIfDirty(value.wrappedValue != saved)
        }
    }

    private func secureRow(_ label: String, hint: String,
                            value: Binding<String>, saved: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            SecureField(hint, text: value)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.leading)
            saveButtonIfDirty(value.wrappedValue != saved)
        }
    }

    @ViewBuilder
    private func saveButtonIfDirty(_ isDirty: Bool) -> some View {
        if isDirty {
            Button("Save") { save() }
                .buttonStyle(.frostPrimary)
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
        }
    }

    // MARK: - Config I/O

    private func loadConfig() {
        guard let loaded = try? configManager.load() else { return }
        config = loaded
        savedConfig = loaded
    }

    private func save() {
        do {
            try configManager.save(config)
            withAnimation { savedConfig = config }
            saveError = nil
            savedConfirmation = true
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                savedConfirmation = false
            }
        } catch {
            saveError = error.localizedDescription
        }
    }
}
