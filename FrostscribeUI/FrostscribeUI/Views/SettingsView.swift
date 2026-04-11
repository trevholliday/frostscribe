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
            Section("Worker") {
                WorkerHealthSection()
            }
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

            Section("Encoder & Quality") {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Skip encoding for DVDs", isOn: $config.skipEncodingDVD)
                        .tint(FrostTheme.frostCyan)
                        .onChange(of: config.skipEncodingDVD) { save() }
                    Text("Raw MKV is moved directly to the library. Recommended when storage is not a concern.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                encoderQualityRow("DVD",     encoder: $config.encoderTypeDVD,     quality: $config.qualityDVD)
                encoderQualityRow("Blu-ray", encoder: $config.encoderTypeBluray,  quality: $config.qualityBluray)
                encoderQualityRow("UHD",     encoder: $config.encoderTypeUHD,     quality: $config.qualityUHD)
            }

            Section("Options") {
                textRow("Event hook", hint: "/path/to/notify.sh", value: $config.eventHook, saved: savedConfig.eventHook)
                vigilModeToggle
                Toggle("Select audio tracks before ripping", isOn: $config.selectAudioTracks)
                    .tint(FrostTheme.frostCyan)
                    .onChange(of: config.selectAudioTracks) { save() }
                Toggle("Filter movie titles under 60 minutes", isOn: $config.filterMovieTitles)
                    .tint(FrostTheme.frostCyan)
                    .onChange(of: config.filterMovieTitles) { save() }
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
        .scrollContentBackground(.hidden)
        .background(FrostTheme.background)
        .foregroundStyle(FrostTheme.textPrimary)
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

    private var vigilModeBinding: Binding<Bool> {
        Binding(
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
        )
    }

    private var vigilModeToggle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Vigil Mode", isOn: vigilModeBinding)
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

    // MARK: - Encoder + Quality row

    private func encoderQualityRow(_ label: String,
                                   encoder: Binding<EncoderType>,
                                   quality: Binding<EncodeQuality>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Picker("Encoder", selection: encoder) {
                    ForEach(EncoderType.allCases, id: \.self) { t in
                        Text(t.displayName).tag(t)
                    }
                }
                .onChange(of: encoder.wrappedValue) { save() }
                .labelsHidden()

                Picker("Quality", selection: quality) {
                    ForEach(EncodeQuality.allCases, id: \.self) { q in
                        Text(q.displayName).tag(q)
                    }
                }
                .onChange(of: quality.wrappedValue) { save() }
                .labelsHidden()
            }
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
                .textFieldStyle(.frost)
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
                .textFieldStyle(.frost)
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

// MARK: - Worker health section

private struct WorkerHealthSection: View {
    private struct Health {
        var isRunning = false
        var pid: String = "-"
        var pending = 0
        var running = 0
        var lastLog: String = ""
    }

    @State private var health = Health()
    @State private var reinstalling = false
    private let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: FrostTheme.paddingM) {
            // Status row
            HStack(spacing: 8) {
                Circle()
                    .fill(health.isRunning ? FrostTheme.teal : FrostTheme.alert)
                    .frame(width: 8, height: 8)
                Text(health.isRunning ? "Running (pid \(health.pid))" : "Stopped")
                    .font(.system(size: 15))
                    .foregroundStyle(health.isRunning ? FrostTheme.teal : FrostTheme.alert)
            }

            // Queue counts
            HStack(spacing: FrostTheme.paddingL) {
                statPill(label: "Pending", value: health.pending)
                statPill(label: "Running", value: health.running)
            }

            // Last log line
            if !health.lastLog.isEmpty {
                Text(health.lastLog)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Reinstall button
            Button(reinstalling ? "Reinstalling…" : "Reinstall & Restart Worker") {
                reinstall()
            }
            .buttonStyle(.frostPrimary)
            .disabled(reinstalling)
        }
        .onAppear { refresh() }
        .onReceive(timer) { _ in refresh() }
    }

    private func statPill(label: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.system(size: 19, weight: .bold).monospacedDigit())
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }

    private func refresh() {
        Task.detached {
            // Worker running state — blocking process call, must be off main thread
            let check = Process()
            check.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            check.arguments = ["list"]
            let pipe = Pipe()
            check.standardOutput = pipe
            check.standardError = FileHandle.nullDevice
            try? check.run()
            check.waitUntilExit()
            let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let line = out.split(separator: "\n").first { $0.contains("com.frostscribe.worker") }
            let pid = line?.split(separator: "\t").first.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? "-"

            // Queue counts
            let jobs = (try? RipQueueManager(appSupportURL: ConfigManager.appSupportURL).read()) ?? []
            let pending = jobs.filter { $0.status == .pending }.count
            let running = jobs.filter { $0.status == .ripping }.count

            // Last log line
            let lastLog = LogStore(appSupportURL: ConfigManager.appSupportURL).load(limit: 1).first?.message ?? ""

            await MainActor.run {
                health.isRunning = pid != "-"
                health.pid = pid
                health.pending = pending
                health.running = running
                health.lastLog = lastLog
            }
        }
    }

    private func reinstall() {
        reinstalling = true
        Task.detached {
            let start = Date()
            let p = Process()
            let frostscribeBin = FileManager.default.fileExists(atPath: "/opt/homebrew/bin/frostscribe")
                ? "/opt/homebrew/bin/frostscribe"
                : "/usr/local/bin/frostscribe"
            p.executableURL = URL(fileURLWithPath: frostscribeBin)
            p.arguments = ["worker", "reinstall"]
            p.standardOutput = FileHandle.nullDevice
            p.standardError = FileHandle.nullDevice
            try? p.run()
            p.waitUntilExit()
            // Always show loading for at least 600ms
            let elapsed = Date().timeIntervalSince(start)
            let remaining = 0.6 - elapsed
            if remaining > 0 {
                try? await Task.sleep(for: .seconds(remaining))
            }
            await MainActor.run {
                reinstalling = false
                refresh()
            }
        }
    }
}
