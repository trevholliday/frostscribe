import SwiftUI
import FrostscribeCore

struct SettingsView: View {
    @State private var config      = Config()
    @State private var savedConfig = Config()
    @State private var saveError: String?
    @State private var savedConfirmation = false

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
                    .onChange(of: config.notificationsEnabled) { save() }
                Toggle("Vigil Mode — auto-rip when disc inserted", isOn: $config.vigilMode)
                    .onChange(of: config.vigilMode) { save() }
                Toggle("Select audio tracks before ripping", isOn: $config.selectAudioTracks)
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

    // MARK: - Row helpers

    private func textRow(_ label: String, hint: String,
                         value: Binding<String>, saved: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                TextField(hint, text: value)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                saveButtonIfDirty(value.wrappedValue != saved)
            }
        }
    }

    private func secureRow(_ label: String, hint: String,
                            value: Binding<String>, saved: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                SecureField(hint, text: value)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                saveButtonIfDirty(value.wrappedValue != saved)
            }
        }
    }

    @ViewBuilder
    private func saveButtonIfDirty(_ isDirty: Bool) -> some View {
        if isDirty {
            Button("Save") { save() }
                .font(.caption.bold())
                .foregroundStyle(.black)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(FrostTheme.frostCyan, in: RoundedRectangle(cornerRadius: FrostTheme.cornerRadius))
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
