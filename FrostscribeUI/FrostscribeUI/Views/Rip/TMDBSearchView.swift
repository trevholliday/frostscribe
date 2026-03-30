import SwiftUI
import FrostscribeCore

struct TMDBSearchView: View {
    let vm: RipFlowCoordinator
    let scanResult: DiscScanResult

    @State private var isTV = false
    @State private var query: String
    @State private var showManualEntry = false
    @State private var manualTitle = ""
    @State private var manualYear = String(Calendar.current.component(.year, from: .now))

    init(vm: RipFlowCoordinator, scanResult: DiscScanResult) {
        self.vm = vm
        self.scanResult = scanResult
        let q = scanResult.discName.map {
            $0.replacing("_", with: " ").capitalized
        } ?? ""
        _query = State(initialValue: q)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Abort button row
            HStack {
                Spacer()
                Button("Abort Rip", role: .destructive) { vm.reset() }
                    .buttonStyle(.frostDestructive)
            }
            .padding(.horizontal, FrostTheme.paddingM)
            .padding(.top, FrostTheme.paddingS)

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
                resultsGrid
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
            Text("Searching…").foregroundStyle(.secondary).font(.system(size: 15))
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
                .font(.system(size: 15)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Enter manually") { showManualEntry = true }
                .buttonStyle(.frostPrimary)
            Spacer()
        }
        .padding(FrostTheme.paddingM)
        .frame(maxWidth: .infinity)
    }

    private var resultsGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 180, maximum: 220), spacing: 16)],
                spacing: 16
            ) {
                ForEach(vm.tmdbResults, id: \.id) { result in
                    Button {
                        vm.confirmTMDB(result: result, scanResult: scanResult,
                                       isTV: result.mediaType == .tv)
                    } label: {
                        TMDBResultCard(result: result)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)

            Button("Enter manually…") { showManualEntry = true }
                .buttonStyle(.plain)
                .foregroundStyle(FrostTheme.glacier)
                .padding(.bottom, FrostTheme.paddingM)
        }
    }

    private var manualEntryForm: some View {
        VStack(alignment: .leading, spacing: FrostTheme.spacing) {
            Text("ENTER MANUALLY")
                .font(.system(size: 15, weight: .bold)).foregroundStyle(.secondary)
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

// MARK: - Card

private struct TMDBResultCard: View {
    let result: TMDBClient.SearchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AsyncImage(url: result.posterURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    ZStack {
                        Color.white.opacity(0.04)
                        VStack(spacing: 6) {
                            Image(systemName: "film")
                                .font(.system(size: 35))
                                .foregroundStyle(FrostTheme.teal.opacity(0.35))
                            Text(result.title)
                                .font(.system(size: 14))
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8)
                        }
                    }
                }
            }
            .aspectRatio(2/3, contentMode: .fit)
            .clipped()

            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.system(size: 19, weight: .bold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Text(result.year)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(result.mediaType == .tv ? "TV" : "Movie")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(FrostTheme.teal)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(FrostTheme.teal.opacity(0.15), in: Capsule())
                }
            }
            .padding(8)
        }
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}
