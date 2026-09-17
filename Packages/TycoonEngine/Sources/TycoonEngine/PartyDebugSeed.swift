import Foundation
import TycoonContent

// MARK: X4 (the launch party)

/// `-autoRoute x4-…` / `-autoParty <scenario>`: dresses the loaded save so
/// one party situation is on screen for a screenshot. Applied only in debug
/// builds; nothing in the game sends `.partyDebugSeed`, so the release binary
/// and every bot, fixture and replay never reach a line of it.
///
/// - `open` — a build that shipped today, reviewed well, the window open and
///   the cash and the evening there: the sheet with three affordable venues.
/// - `desperate` — the same launch with the reviews dragged under the
///   rooftop's bar, so the sheet reads the rooftop back as what it is.
/// - `thrown` — the party already thrown on the rooftop, for the aftermath.
/// - `away` — the founder somewhere else, for the row that says so.
enum PartyDebugSeed {
    static func apply(
        scenario: String,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard let product = recentRelease(state) else { return [] }
        state.company.cash = max(state.company.cash, 40_000)
        state.life.eveningsSpentThisWeek = 0

        switch scenario {
        case "open":
            setReviews(to: 84, productID: product, state: &state)
            landToday(productID: product, state: &state)
            return []
        case "desperate":
            setReviews(to: 55, productID: product, state: &state)
            landToday(productID: product, state: &state)
            return []
        case "thrown":
            setReviews(to: 84, productID: product, state: &state)
            landToday(productID: product, state: &state)
            let guests = Array(
                state.partyGuestPool(productID: product, balance: balance)
                    .prefix(balance.party.rooftop.guests)
            )
            return PartySystem.throwParty(
                productID: product, venue: .rooftop, guests: guests,
                state: &state, balance: balance, content: content
            )
        case "away":
            setReviews(to: 84, productID: product, state: &state)
            landToday(productID: product, state: &state)
            state.doors.armed = true
            state.life.awaySinceDay = state.day
            state.life.awayUntilDay = state.day + 5
            state.life.awayReason = "away on a course"
            return []
        default:
            return []
        }
    }

    /// The newest release, or the newest product of any kind — the fixtures
    /// this dresses all have one.
    private static func recentRelease(_ state: GameState) -> UUID? {
        let released = state.products.filter {
            if case .released = $0.stage { return true } else { return false }
        }
        return released.last?.id ?? state.products.last?.id
    }

    /// Moves the launch to today, so the window is open at its widest.
    private static func landToday(productID: UUID, state: inout GameState) {
        guard let index = state.products.firstIndex(where: { $0.id == productID }),
              case .released(var info) = state.products[index].stage
        else { return }
        info.launchDay = state.day
        info.embargoUntilDay = nil
        info.exclusiveOutlet = nil
        state.products[index].stage = .released(info)
    }

    /// Puts every outlet on `score`, so the slope reads exactly what the
    /// screenshot is about.
    private static func setReviews(to score: Int, productID: UUID, state: inout GameState) {
        guard let index = state.products.firstIndex(where: { $0.id == productID }),
              case .released(var info) = state.products[index].stage
        else { return }
        for reviewIndex in info.reviews.indices { info.reviews[reviewIndex].score = score }
        state.products[index].stage = .released(info)
    }
}

// MARK: end X4
