import SwiftUI
import FrostscribeCore

struct SettingsView: View {
    @State private var moviesDir = ""
    @State private var tvDir = ""
    @State private var tempDir = ""
    @State private var mediaServer = MediaServer.jellyfin
    @State private var tmdbKey = ""
    @State private var makemkvKey = ""
    @State private var makemkvBin = ""
    @State private var handbrakeBin = ""
    @State private var notificationsEnabled = true
    @State private var vigilMode = false
    @State private var saveError: String?
    @State private var savedConfirmation = false

    private let configManager = ConfigManager()

    var body: some View {
        Form {
            Section("Paths") {
                LabeledContent("Movies directory") {
                    TextField("e.g. /Volumes/Media/Movies", text: $moviesDir)
                        .textFieldStyle(.roundedBorder)
                }
                LabeledContent("TV Shows directory") {
                    TextField("e.g. /Volumes/Media/TV Shows", text: $tvDir)
                        .textFieldStyle(.roundedBorder)
                }
                LabeledContent("Temp directory") {
                    TextField("e.g. /tmp/frostscribe", text: $tempDir)
                        .textFieldStyle(.roundedBorder)
                }
            }

            Section("Media") {
                Picker("Media server", selection: $mediaServer) {
                    ForEach(MediaServer.allCases, id: \.self) { server in
                        Text(server.rawValue.capitalized).tag(server)
                    }
                }
            }

            Section("Tools & API Keys") {
                LabeledContent("makemkvcon path") {
                    TextField("e.g. /opt/homebrew/bin/makemkvcon", text: $makemkvBin)
                        .textFieldStyle(.roundedBorder)
                }
                LabeledContent("HandBrakeCLI path") {
                    TextField("e.g. /opt/homebrew/bin/HandBrakeCLI", text: $handbrakeBin)
                        .textFieldStyle(.roundedBorder)
                }
                LabeledContent("MakeMKV key") {
                    SecureField("optional", text: $makemkvKey)
                        .textFieldStyle(.roundedBorder)
                }
                LabeledContent("TMDB API key") {
                    SecureField("optional", text: $tmdbKey)
                        .textFieldStyle(.roundedBorder)
                }
            }

            Section("Options") {
                Toggle("Enable notifications", isOn: $notificationsEnabled)
                Toggle("Vigil Mode — auto-rip when disc is inserted", isOn: $vigilMode)
                Toggle("Select audio tracks before ripping", isOn: $selectAudioTracks)
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
        .frame(width: 500, height: 440)
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: saveConfig)
            }
        }
        .overlay(alignment: .bottom) {
            if savedConfirmation {
                Label("Settings saved", systemImage: "checkmark.circle.fill")
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

    // MARK: - Config I/O

    private func loadConfig() {
        guard let config = try? configManager.load() else { return }
        moviesDir            = config.moviesDir
        tvDir                = config.tvDir
        tempDir              = config.tempDir
        mediaServer          = config.mediaServer
        tmdbKey              = config.tmdbApiKey
        makemkvKey           = config.makemkvKey
        makemkvBin           = config.makemkvBin
        handbrakeBin         = config.handbrakeBin
        notificationsEnabled = config.notificationsEnabled
        vigilMode            = config.vigilMode
    }

    private func saveConfig() {
        let config = Config(
            mediaServer:          mediaServer,
            moviesDir:            moviesDir,
            tvDir:                tvDir,
            tempDir:              tempDir,
            tmdbApiKey:           tmdbKey,
            makemkvKey:           makemkvKey,
            makemkvBin:           makemkvBin,
            handbrakeBin:         handbrakeBin,
            notificationsEnabled: notificationsEnabled,
            vigilMode:            vigilMode
        )
        do {
            try configManager.save(config)
            saveError = nil
            savedConfirmation = true
            Task {
                try? await Task.sleep(for: .seconds(2))
                savedConfirmation = false
            }
        } catch {
            saveError = error.localizedDescription
        }
    }
}
