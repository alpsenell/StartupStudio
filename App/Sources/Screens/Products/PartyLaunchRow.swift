import SwiftUI
import TycoonEngine

// MARK: X4 (the launch party)

/// Iteration 18 — X4. The party row: on the launch-day sheet's actions and
/// on the war room's aftermath.
///
/// Draws nothing at all outside the window, on a launch that already had its
/// party, or on one where the date was kept instead — the house shape for a
/// launch-sheet row (`DiaryKeepDateRow`, `PreorderLaunchRow`), so the sheet
/// can name it unconditionally.
struct PartyLaunchRow: View {
    let engine: GameEngine
    let product: Product

    @State private var throwing = false

    private var state: GameState { engine.state }

    var body: some View {
        if let party = state.party(for: product.id) {
            thrown(party)
        } else if state.partyWindowIsOpen(productID: product.id, balance: engine.balance),
                  !state.diaryDateWasKept(productID: product.id) {
            offer
        }
    }

    // MARK: - Before

    private var offer: some View {
        // The cheapest venue answers "can I do this at all?" — the sheet
        // prices all three.
        let blocker = state.launchPartyBlocker(
            productID: product.id, venue: .office, balance: engine.balance
        )
        let away = state.life.isAway(day: state.day)
        return PixelPanel(contentPadding: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                PixelSectionTitle(title: "The party")
                Text(away ? state.awayPartyReason + "." : pitch)
                    .font(.callout)
                    .foregroundStyle(away ? Theme.warning : Theme.pixelInk)
                    .fixedSize(horizontal: false, vertical: true)
                if !away {
                    Button {
                        Haptics.tap()
                        throwing = true
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Throw a launch party")
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(Theme.accent)
                            Text("\(engine.balance.party.office.cost.money) in the office, "
                                + "\(engine.balance.party.bar.cost.money) at the bar, "
                                + "\(engine.balance.party.rooftop.cost.money) on the roof — and one of your evenings.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            if let blocker {
                                Text(blocker)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Theme.warning)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Theme.Spacing.md)
                        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.pressableRow)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $throwing) {
            PartySheet(engine: engine, product: product)
        }
    }

    private var pitch: String {
        let left = daysLeft
        let score = state.partyReviewScore(productID: product.id)
        let when = left <= 0
            ? "Tonight, or it stops being a launch party."
            : "There are \(left) day\(left == 1 ? "" : "s") left to call it one."
        guard score > 0 else { return "It is out. \(when)" }
        return score >= 75
            ? "They liked it. \(when)"
            : "It is out, at \(score). \(when)"
    }

    private var daysLeft: Int {
        guard case .released(let info) = product.stage else { return 0 }
        return max(0, engine.balance.party.windowDays - (state.day - info.launchDay))
    }

    // MARK: - After

    private func thrown(_ party: LaunchParty) -> some View {
        PixelPanel(contentPadding: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                PixelSectionTitle(title: "The party")
                Text(PartyCopy.aftermath(party, product: product))
                    .font(.callout)
                    .foregroundStyle(Theme.pixelInk)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    Haptics.tap()
                    throwing = true
                } label: {
                    Label("See the room", systemImage: "party.popper.fill")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $throwing) {
            PartySheet(engine: engine, product: product)
        }
    }
}

// MARK: end X4

// MARK: X4 (the launch party) — the screenshot pass

private struct PartyAutoRoute: ViewModifier {
    let engine: GameEngine

    func body(content: Content) -> some View {
        content.task {
            #if DEBUG
            guard let route = DebugLaunch.launchRoute, route.hasPrefix("x4-") else { return }
            // Let the save settle and the products list appear first.
            for _ in 0..<20 where engine.state.products.isEmpty {
                try? await Task.sleep(for: .seconds(1))
            }
            try? await Task.sleep(for: .seconds(2))
            DebugLaunch.x4DressIfAsked(engine: engine)
            #endif
        }
    }
}

extension View {
    /// One line in `ProductsScreen`; everything `-autoRoute x4-…` does lives
    /// in `DebugLaunch.x4DressIfAsked` and `PartyDebugSeed`.
    func partyAutoRoute(engine: GameEngine) -> some View {
        modifier(PartyAutoRoute(engine: engine))
    }
}

// MARK: end X4
