import Foundation
import TycoonContent

// MARK: X4 (the launch party)

/// Iteration 18 — X4. Throwing the launch party.
///
/// One action, `.throwLaunchParty(productID:venue:guests:)`, valid for
/// `party.windowDays` after a launch and once per launch. It spends company
/// cash and the founder's own evening — the scarcest thing in the game — and
/// pays in five currencies the game already keeps: everybody's morale, the
/// release's `liveHype`, the outlets' standing, the address book's rapport,
/// and (on crunch) the vices' weekly pressure.
///
/// **The slope is the decision.** The hype a party buys is the venue's
/// number times `(review − 60) / 25`: a rooftop for a hit is the best money
/// in the game and a rooftop for a 55 is a photograph of a company that does
/// not know it has failed — negative hype, every outlet a point colder, and
/// the paper saying so. There is no venue that is right for every launch,
/// which is the only thing that stops the biggest one being automatic.
///
/// Nothing here draws from any stream, and no bot sends the action, so a run
/// that never parties is byte for byte the run it always was.
enum PartySystem {
    /// Throws the party. Refused — silently, as every action is — for the
    /// reasons `GameState.launchPartyBlocker` names, which is the same
    /// function the button reads before it is tapped.
    static func throwParty(
        productID: UUID,
        venue: PartyVenue,
        guests: [PartyGuest],
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard state.launchPartyBlocker(productID: productID, venue: venue, balance: balance) == nil,
              let index = state.products.firstIndex(where: { $0.id == productID }),
              case .released(var info) = state.products[index].stage
        else { return [] }

        let config = balance.party
        let quote = state.partyQuote(productID: productID, venue: venue, balance: balance)
        // The list the sheet sent, cut to what the venue holds and to people
        // who are actually invitable — a stale sheet cannot smuggle a name in.
        let list = invited(guests, productID: productID, limit: quote.guestLimit, state: state, balance: balance)

        // The bill, and the evening.
        state.company.cash -= quote.cost
        state.ledger.post(LedgerEntry(
            day: state.day, amount: -quote.cost, category: .marketing,
            label: "Launch party: \(venue.displayName.lowercased())"
        ))
        state.spendEvening(balance)

        // The room. Everyone on payroll was there.
        moraleAll(quote.morale, state: &state)

        // What the press and the market make of it. `liveHype` is what a
        // campaign after launch buys, and this is a campaign after launch
        // — one that can run backwards.
        info.liveHype = max(0, info.liveHype + quote.hype)
        state.products[index].stage = .released(info)

        applyPress(quote: quote, invited: list, state: &state, balance: balance)
        applyBonds(invited: list, state: &state, balance: balance)

        state.parties.append(LaunchParty(
            productID: productID, venue: venue, day: state.day, guests: list,
            reviewScore: quote.reviewScore, hype: quote.hype, desperate: quote.desperate
        ))

        // MARK: K7 (partner and diary) — a party on a diary date clashes
        // exactly as a launch does: the same flag, the same window, and the
        // diary asks on the day as it always does.
        DiaryRoadmap.noteLaunch(&state, balance: balance, content: content)
        // MARK: end K7

        return [.launchPartyThrown(
            productID: productID, venue: venue.rawValue, cost: quote.cost,
            hype: quote.hype, guests: list.count, desperate: quote.desperate, day: state.day
        )]
    }

    /// The guest list as the engine will honour it: outlets and contacts the
    /// pool actually offers, de-duplicated, in the order the sheet sent them,
    /// cut to the venue's capacity.
    private static func invited(
        _ guests: [PartyGuest],
        productID: UUID,
        limit: Int,
        state: GameState,
        balance: BalanceConfig
    ) -> [PartyGuest] {
        let pool = Set(state.partyGuestPool(productID: productID, balance: balance))
        var seen: Set<PartyGuest> = []
        var list: [PartyGuest] = []
        for guest in guests where pool.contains(guest) && seen.insert(guest).inserted {
            list.append(guest)
            if list.count >= max(0, limit) { break }
        }
        return list
    }

    /// Everybody on payroll, the `teamDinner` shape. The founder's own
    /// morale is not a number the game keeps; theirs is the mood meter, and
    /// the party does not touch it — this is the room's night, not a
    /// wellbeing purchase.
    private static func moraleAll(_ delta: Double, state: inout GameState) {
        for index in state.employees.indices where !state.employees[index].isFounder {
            state.employees[index].morale = min(100, max(0, state.employees[index].morale + delta))
        }
    }

    /// The outlets who came warm to the studio; if the venue was more than
    /// the reviews earned, *every* outlet cools, including the ones who
    /// drank the champagne. Standing is clamped to ±`press.cap` and written
    /// `nil` at zero, exactly as the exclusive does, so a run that never
    /// parties and never gave an exclusive keeps an empty map.
    private static func applyPress(
        quote: PartyQuote,
        invited: [PartyGuest],
        state: inout GameState,
        balance: BalanceConfig
    ) {
        let cap = balance.press.cap
        var attending: Set<String> = []
        for guest in invited { if case .outlet(let name) = guest { attending.insert(name) } }
        guard !attending.isEmpty || quote.desperate else { return }
        for name in balance.reviewOutlets {
            var delta = attending.contains(name) ? quote.outletStanding : 0
            delta += quote.desperatePenalty
            guard delta != 0 else { continue }
            let moved = min(cap, max(-cap, state.company.pressStanding(of: name) + delta))
            state.company.pressStanding[name] = moved == 0 ? nil : moved
        }
    }

    /// The address book: somebody who stood in your room on the night is
    /// somebody you have a little more of a claim on. Rapport, and the day
    /// counts as having seen them.
    private static func applyBonds(
        invited: [PartyGuest],
        state: inout GameState,
        balance: BalanceConfig
    ) {
        let bond = balance.party.bondPerGuest
        guard bond != 0 else { return }
        for guest in invited {
            guard case .contact(let id) = guest,
                  let index = state.networking.contacts.firstIndex(where: { $0.id == id })
            else { continue }
            state.networking.contacts[index].rapport = min(
                100, max(0, state.networking.contacts[index].rapport + bond)
            )
            state.networking.contacts[index].lastMetDay = state.day
        }
    }
}

// MARK: end X4
