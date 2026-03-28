import SwiftUI
import FrostscribeCore

struct TMDBSearchView: View {
    let vm: RipFlowViewModel
    let scanResult: DiscScanResult

    @State private var isTV = false
    @State private var query: String
    @State private var showManualEntry = false
    @State private var manualTitle = ""
    @State private var manualYear = String(Calendar.current.component(.year, from: Date()))

    init(vm: RipFlowViewModel, scanResult: DiscScanResult) {
        self.vm = vm
        self.scanResult = scanResult
        let q = scanResult.discName.map {
            $0.replacingOccurrences(of: "_", with: " ").capitalized
        } ?? ""
        _query = State(initialValue: q)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Media type + search bar
            VStack(spacing: FrostTheme.spacing) {
                Picker("Media Type", selection: $isTV) {
                    Text("Movie").tag(false)
                    Text("TV Show").tag(true)
                }
                .pickerStyle(.segmented)
                .onChange(of: isTV) { search() }

                HStack(spacing: FrostTheme.spacing) {
                    TextField("Search TMDB…", text: $query)
                        .textFieldStyle(.frost)
                        .onSubmit { search() }
                    Button("Search", action: search)
                        .buttonStyle(.frostPrimary)
                }
            }
            .padding(FrostTheme.paddingM)

            Divider()

            if !vm.isTMDBConfigured {
                noKeyPrompt
            } else if vm.isSearching {
                searchingView
            } else if vm.tmdbResults.isEmpty && !showManualEntry {
                emptyState
            } else {
                resultsList
            }

            if showManualEntry {
                Divider()
                manualEntryForm
            }
        }
        .onAppear {
            if vm.isTMDBConfigured && !query.isEmpty && vm.tmdbResults.isEmpty {
                search()
            }
        }
    }

    // MARK: - Sub-views

    private var searchingView: some View {
        VStack {
            Spacer()
            ProgressView().tint(FrostTheme.frostCyan)
            Text("Searching…").foregroundStyle(.secondary).font(.caption)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: FrostTheme.spacing) {
            Spacer()
            Text("No results").foregroundStyle(.secondary)
            Button("Enter manually") { showManualEntry = true }
                .buttonStyle(.plain)
                .foregroundStyle(FrostTheme.glacier)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var noKeyPrompt: some View {
        VStack(spacing: FrostTheme.spacing) {
            Spacer()
            Text("No TMDB key configured.").foregroundStyle(.secondary)
            Text("Add one in Settings, or enter the title manually.")
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Enter manually") { showManualEntry = true }
                .buttonStyle(.frostPrimary)
            Spacer()
        }
        .padding(FrostTheme.paddingM)
        .frame(maxWidth: .infinity)
    }

    private var resultsList: some View {
        List {
            ForEach(vm.tmdbResults, id: \.id) { result in
                HStack(spacing: FrostTheme.paddingM) {
                    AsyncImage(url: result.posterURL) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        default:
                            ZStack {
                                FrostTheme.background
                                Image(systemName: "snowflake")
                                    .foregroundStyle(FrostTheme.teal.opacity(0.4))
                            }
                        }
                    }
                    .frame(width: 36, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.title).bold().lineLimit(1)
                        Text("\(result.year) · \(result.mediaType == .tv ? "TV" : "Movie")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    vm.confirmTMDB(result: result, scanResult: scanResult,
                                   isTV: result.mediaType == .tv)
                }
            }
            Button("Enter manually…") { showManualEntry = true }
                .buttonStyle(.plain)
                .foregroundStyle(FrostTheme.glacier)
        }
        .listStyle(.plain)
    }

    private var manualEntryForm: some View {
        VStack(alignment: .leading, spacing: FrostTheme.spacing) {
            Text("ENTER MANUALLY")
                .font(.caption).bold().foregroundStyle(.secondary)
            HStack(spacing: FrostTheme.spacing) {
                TextField("Title", text: $manualTitle)
                    .textFieldStyle(.frost)
                TextField("Year", text: $manualYear)
                    .textFieldStyle(.frost)
                    .frame(width: 72)
            }
            HStack {
                Button("Cancel") { showManualEntry = false }
                    .buttonStyle(.frostDestructive)
                Spacer()
                Button("Continue") {
                    vm.enterManually(title: manualTitle, year: manualYear,
                                     scanResult: scanResult, isTV: isTV)
                }
                .buttonStyle(.frostPrimary)
                .disabled(manualTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(FrostTheme.paddingM)
    }

    // MARK: - Actions

    private func search() {
        vm.searchTMDB(query: query, scanResult: scanResult, isTV: isTV)
    }
}
