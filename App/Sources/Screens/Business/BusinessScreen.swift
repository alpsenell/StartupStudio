import SwiftUI
import TycoonEngine

/// The Business tab: client contracts, the market, marketing campaigns,
/// finances, rivals and investors, switched with a pill bar pinned above
/// the scroll content (nav-bar toolbars sit underneath the opaque top HUD
/// in this design, and content inside the ScrollView would scroll under
/// the HUD).
struct BusinessScreen: View {
    let engine: GameEngine

    private enum BusinessSection: String, CaseIterable, Identifiable {
        case contracts = "Contracts"
        case market = "Market"
        case marketing = "Marketing"
        case finances = "Finances"
        case rivals = "Rivals"
        case investors = "Investors"

        var id: String { rawValue }

        /// Each section's own icon, taken from the headers inside it, so
        /// the pill and the screen it opens agree.
        var systemImage: String {
            switch self {
            case .contracts: "briefcase.fill"
            case .market: "chart.xyaxis.line"
            case .marketing: "megaphone.fill"
            case .finances: "banknote.fill"
            case .rivals: "flag.2.crossed.fill"
            case .investors: "chart.pie.fill"
            }
        }
    }

    @State private var section: BusinessSection = .contracts

    @Environment(AppRouter.self) private var router

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Pinned below the top HUD inset, outside the ScrollView,
                // so it can never scroll under the opaque HUD.
                //
                // Six segments do not fit an iPhone as a segmented picker:
                // they truncate to "Contr…" / "Market…" / "Investo…" at the
                // default text size, and worse above it. The pill bar keeps
                // every label whole and scrolls instead.
                SegmentPillBar(
                    segments: BusinessSection.allCases,
                    title: \.rawValue,
                    systemImage: \.systemImage,
                    accessibilityLabel: "Business section",
                    selection: $section
                )
                .padding(.top, Theme.Spacing.xs)
                .background(Theme.screenBackground)
                .overlay(alignment: .bottom) { Divider() }

                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        switch section {
                        case .contracts:
                            ContractsView(engine: engine)
                        case .market:
                            MarketView(engine: engine)
                        case .marketing:
                            MarketingView(engine: engine)
                        case .finances:
                            FinancesView(engine: engine)
                        case .rivals:
                            RivalsView(engine: engine)
                        case .investors:
                            InvestorsView(engine: engine)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.sm)
                    .padding(.bottom, Theme.Spacing.lg)
                }
            }
            // The HUD inset lives on the stack's root content (this VStack),
            // not on the NavigationStack, so the pill bar lands below it.
            .withTopHUD(engine: engine)
            .background(Theme.screenBackground)
            .navigationTitle("Business")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            // Deep links into this tab pick their own segment.
            .onChange(of: router.pendingPush, initial: true) { _, _ in
                consumeRoute()
            }
        }
    }

    /// Switches to the segment a deep link asked for.
    ///
    /// Routes this screen can satisfy on its own are consumed here;
    /// `.marketReport` only picks the segment and is left in place for
    /// `MarketView` to open the report on the right topic.
    private func consumeRoute() {
        switch router.pendingPush {
        case .contracts:
            section = .contracts
            router.take(.contracts)
        case .market:
            section = .market
            router.take(.market)
        case .marketing:
            section = .marketing
            router.take(.marketing)
        case .finances:
            section = .finances
            router.take(.finances)
        case .marketReport:
            section = .market
        default:
            break
        }
    }
}

// MARK: - Shared section header

/// Section label above a run of cards, matching the CardView header look.
struct BusinessSectionHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: systemImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.accent)
            Text(title)
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .textCase(.uppercase)
                .kerning(0.6)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.xs)
        .accessibilityAddTraits(.isHeader)
    }
}
