import SwiftUI
import FrostscribeCore

// MARK: - Ripping screen (carousel + media details)

struct RipRippingView: View {
    let vm: RipFlowViewModel

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                PeekingCarouselView(imageURLs: vm.carouselURLs)
                    .frame(height: geo.size.height * 0.45)

                let hasDetails = vm.mediaDetails != nil || !vm.carouselURLs.isEmpty
                if hasDetails {
                    Divider().opacity(0.2)

                    ScrollView {
                        mediaDetails
                            .padding(FrostTheme.paddingL)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: .infinity)
                }
            }
        }
    }

    // MARK: - Media details

    @ViewBuilder
    private var mediaDetails: some View {
        if let details = vm.mediaDetails {
            VStack(alignment: .leading, spacing: FrostTheme.paddingL) {
                // Tagline
                if let tagline = details.tagline {
                    Text(tagline)
                        .italic()
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                // Overview
                if let overview = details.overview {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Overview")
                            .font(.headline)
                        Text(overview)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                // Crew grid
                if !details.crew.isEmpty {
                    crewGrid(details.crew)
                }
            }
        } else if !vm.carouselURLs.isEmpty {
            // TMDB data was fetched but details haven't arrived yet
            VStack(spacing: FrostTheme.paddingM) {
                ProgressView().tint(FrostTheme.frostCyan)
                Text("Loading details…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, FrostTheme.paddingL)
        }
    }

    private func crewGrid(_ crew: [MediaDetails.CrewMember]) -> some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: FrostTheme.paddingM) {
            ForEach(Array(crew.enumerated()), id: \.offset) { _, member in
                VStack(alignment: .leading, spacing: 2) {
                    Text(member.name)
                        .font(.subheadline).bold()
                        .lineLimit(1)
                    Text(member.job)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Peeking carousel

struct PeekingCarouselView: View {
    let imageURLs: [URL]

    @State private var currentIndex: Int = 0

    private static let slideDuration: Double = 0.5
    private static let cardFraction: CGFloat = 0.35
    private static let spacing: CGFloat = 14
    private let timer = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    private var looped: [URL] {
        guard imageURLs.count > 1 else { return imageURLs }
        return imageURLs + imageURLs + imageURLs
    }

    var body: some View {
        GeometryReader { geo in
            let cardWidth = geo.size.width * Self.cardFraction
            let offsetX = CGFloat(currentIndex) * (cardWidth + Self.spacing)
            let centerX = (geo.size.width - cardWidth) / 2

            if imageURLs.isEmpty {
                placeholderCard(width: geo.size.width, height: geo.size.height)
            } else if imageURLs.count == 1 {
                carouselCard(url: imageURLs[0], width: cardWidth, height: geo.size.height)
                    .frame(width: geo.size.width, height: geo.size.height)
            } else {
                HStack(spacing: Self.spacing) {
                    ForEach(Array(looped.enumerated()), id: \.offset) { _, url in
                        carouselCard(url: url, width: cardWidth, height: geo.size.height)
                    }
                }
                .offset(x: centerX - offsetX)
                .onAppear { currentIndex = imageURLs.count }
                .onReceive(timer) { _ in advance(cardWidth: cardWidth) }
            }
        }
        .clipped()
    }

    private func carouselCard(url: URL, width: CGFloat, height: CGFloat) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            default:
                placeholderContent
            }
        }
        .frame(width: width, height: height)
        .background(Color.black.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func placeholderCard(width: CGFloat, height: CGFloat) -> some View {
        placeholderContent.frame(width: width, height: height)
    }

    private var placeholderContent: some View {
        ZStack {
            FrostTheme.background
            Image(systemName: "snowflake")
                .font(.system(size: 48))
                .foregroundStyle(FrostTheme.teal.opacity(0.2))
        }
    }

    private func advance(cardWidth: CGFloat) {
        guard imageURLs.count > 1 else { return }
        withAnimation(.easeInOut(duration: Self.slideDuration)) {
            currentIndex += 1
        }
        if currentIndex >= imageURLs.count * 2 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.slideDuration + 0.05) {
                var t = Transaction()
                t.disablesAnimations = true
                withTransaction(t) { currentIndex = imageURLs.count }
            }
        }
    }
}
