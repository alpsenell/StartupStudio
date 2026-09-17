import PixelKit
import SwiftUI
import TycoonEngine

// MARK: X4 (the launch party)

/// Iteration 18 — X4. Throw the launch party.
///
/// The sheet is the networking floor's grammar turned on the player's own
/// company: a room with a backdrop, a floor line, and *your roster* standing
/// in it — the people who actually built the thing, drawn from the same
/// appearance seeds the office draws them from — with the press and the
/// address-book names you put on the list beside them. The venue rows under
/// it are the decision, and the room above them changes as you read it.
///
/// Every row prints the house money line (`DecisionPrompt.afterState`), and
/// every refusal comes from the engine's own `launchPartyBlocker`, so the
/// button never offers something the reducer will decline.
struct PartySheet: View {
    let engine: GameEngine
    let product: Product

    @State private var venue: PartyVenue = .bar
    @State private var guests: [PartyGuest] = []
    /// Set once the party is sent, so the sheet plays the night rather than
    /// closing on the moment it exists for.
    @State private var thrown = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// See `GameShell.shared`: read optionally, because SwiftUI updates this
    /// property for presented content before the environment is installed.
    private var shell: GameShell { injectedShell ?? .shared }

    private var state: GameState { engine.state }
    private var balance: BalanceConfig { engine.balance }

    /// The party as thrown, once it has been.
    private var party: LaunchParty? { state.party(for: product.id) }

    private var quote: PartyQuote {
        state.partyQuote(productID: product.id, venue: venue, balance: balance)
    }

    private var blocker: String? {
        state.launchPartyBlocker(productID: product.id, venue: venue, balance: balance)
    }

    private var pool: [PartyGuest] {
        state.partyGuestPool(productID: product.id, balance: balance)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    PartyFloorView(
                        venue: party?.venue ?? venue,
                        team: team,
                        guests: sceneGuests,
                        founderSeed: founderSeed,
                        reduceMotion: reduceMotion
                    )
                    .frame(height: 330)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))

                    if let party {
                        aftermath(party)
                    } else {
                        header
                        // T6: no founder, no party. The launch already said
                        // so; this says it about the night itself.
                        if state.life.isAway(day: state.day) {
                            awayRow
                        } else {
                            venues
                            guestList
                            // K7: the diary asks on the day, as it always does.
                            diaryRow
                            commit
                        }
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.screenBackground)
            .navigationTitle(party == nil ? "Throw a party" : "The party")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(party == nil ? "Not tonight" : "Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .onAppear { if guests.isEmpty { guests = Array(pool.prefix(quote.guestLimit)) } }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            PixelSectionTitle(title: "\(product.name) is out")
            Text(headline)
                .font(.callout)
                .foregroundStyle(Theme.pixelInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headline: String {
        let score = state.partyReviewScore(productID: product.id)
        let left = daysLeft
        let window = left <= 0
            ? "Tonight is the last night anybody will call it a launch party."
            : "You have \(left) more day\(left == 1 ? "" : "s") to call it a launch party."
        switch score {
        case 80...: return "The press liked it. \(window)"
        case 60..<80: return "It landed at \(score). \(window)"
        case 1..<60: return "It landed at \(score), which everybody in the room has read. \(window)"
        default: return "The verdicts are not in yet. \(window)"
        }
    }

    private var daysLeft: Int {
        guard case .released(let info) = product.stage else { return 0 }
        return max(0, balance.party.windowDays - (state.day - info.launchDay))
    }

    private var awayRow: some View {
        Label(state.awayPartyReason + ".", systemImage: "suitcase.fill")
            .font(.callout)
            .foregroundStyle(Theme.warning)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - The venues

    private var venues: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Where")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
            ForEach(PartyVenue.allCases, id: \.self) { option in
                let optionQuote = state.partyQuote(productID: product.id, venue: option, balance: balance)
                let optionBlocker = state.launchPartyBlocker(
                    productID: product.id, venue: option, balance: balance
                )
                Button {
                    venue = option
                    guests = Array(guests.prefix(optionQuote.guestLimit))
                    if guests.isEmpty { guests = Array(pool.prefix(optionQuote.guestLimit)) }
                } label: {
                    PartyVenueRow(
                        venue: option,
                        quote: optionQuote,
                        money: DecisionPrompt.afterState(
                            delta: -optionQuote.cost,
                            cash: state.company.cash,
                            burn: engine.weeklyBurn
                        ),
                        blocker: optionBlocker,
                        selected: venue == option
                    )
                }
                .buttonStyle(.pressableRow)
                .accessibilityLabel("\(option.displayName), \(optionQuote.cost.money)")
                .accessibilityAddTraits(venue == option ? .isSelected : [])
            }
        }
    }

    // MARK: - The list

    private var guestList: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("Who")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Spacer(minLength: 0)
                Text("\(guests.count) of \(quote.guestLimit)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if pool.isEmpty {
                Text("Nobody to invite yet — the press have not filed and the address book is empty.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                PartyGuestFlow(
                    pool: pool,
                    guests: $guests,
                    limit: quote.guestLimit,
                    name: name(of:)
                )
                Text(listNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var listNote: String {
        let standing = Int(quote.outletStanding.rounded())
        let bond = Int(quote.bond.rounded())
        if quote.desperate {
            let cost = Int(abs(quote.desperatePenalty).rounded())
            return "An outlet in the room warms by \(standing) — but a \(venue.displayName.lowercased()) "
                + "for a \(quote.reviewScore) reads as what it is, and every outlet cools by \(cost) for it. "
                + "A name from the book still gains \(bond) rapport."
        }
        return "An outlet in the room warms by \(standing); a name from the book gains \(bond) rapport."
    }

    // MARK: - The diary

    @ViewBuilder
    private var diaryRow: some View {
        if let clash = state.diaryDates(
            near: state.day, window: balance.partner.launchWindowDays, content: engine.content
        ).first {
            Label(
                "\(clash.label) is tonight. Throwing the party is choosing the party, "
                    + "and the diary asks on the day as it always does.",
                systemImage: "calendar.badge.exclamationmark"
            )
            .font(.caption)
            .foregroundStyle(Theme.romance)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Commit

    private var commit: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Button {
                Haptics.commit()
                shell.toasts.send(
                    .throwLaunchParty(productID: product.id, venue: venue, guests: guests),
                    to: engine,
                    ack: ackLine,
                    rejected: blocker ?? "Not tonight.",
                    icon: "party.popper.fill"
                )
                thrown = true
            } label: {
                Label("Throw it", systemImage: "party.popper.fill")
                    .font(.system(.headline, design: .rounded))
            }
            .buttonStyle(PixelButtonStyle())
            .disabled(blocker != nil)
            if let blocker {
                Text(blocker)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.warning)
            } else {
                Text("One evening of yours, and there is no second party for this launch.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var ackLine: String {
        quote.desperate
            ? "\(venue.displayName). Everybody came, and everybody had read the reviews."
            : "\(venue.displayName). They stayed late."
    }

    // MARK: - Afterward

    private func aftermath(_ party: LaunchParty) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            PixelSectionTitle(title: "The night")
            Text(PartyCopy.aftermath(party, product: product))
                .font(.callout)
                .foregroundStyle(Theme.pixelInk)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .top, spacing: Theme.Spacing.xl) {
                LaunchStat(
                    label: String(localized: "Morale", comment: "Launch party figure: what the night did for the room"),
                    value: "+\(Int(balance.party.venue(party.venue).morale.rounded()))",
                    tint: Theme.positiveCash
                )
                LaunchStat(
                    label: String(localized: "Hype", comment: "Launch party figure: what the night did for the product's attention"),
                    value: party.hype >= 0
                        ? "+\(Int(party.hype.rounded()))"
                        : "−\(Int(abs(party.hype).rounded()))",
                    tint: party.hype >= 0 ? Theme.positiveCash : Theme.warning
                )
                LaunchStat(
                    label: String(localized: "Guests", comment: "Launch party figure: how many came"),
                    value: "\(party.guests.count)"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - The room

    /// The roster, founder last so the floor reads front-to-back the way the
    /// networking room does. Anybody away is not in the building.
    private var team: [PartyPerson] {
        state.employees
            .filter { !$0.isFounder && !$0.isAway(on: state.day) }
            .sorted { $0.hiredDay < $1.hiredDay }
            .map { PartyPerson(id: $0.id, name: $0.name, seed: $0.appearanceSeed, isPress: false) }
    }

    /// The list, as people to draw. The scene shows what is chosen, so the
    /// room fills up as the list does.
    private var sceneGuests: [PartyPerson] {
        (party?.guests ?? guests).map { guest in
            switch guest {
            case .outlet(let outlet):
                // A stable id, not a fresh `UUID()`: the figures are keyed
                // on it, and a new one every render restarts every sprite.
                return PartyPerson(
                    id: PartyCopy.id(for: outlet), name: outlet,
                    seed: PartyCopy.seed(for: outlet), isPress: true
                )
            case .contact(let id):
                let contact = state.networking.contact(id)
                return PartyPerson(
                    id: id,
                    name: contact?.name ?? "A guest",
                    seed: contact?.appearanceSeed ?? PartyCopy.seed(for: id.uuidString),
                    isPress: false
                )
            }
        }
    }

    private var founderSeed: UInt64 {
        state.employees.first(where: \.isFounder)?.appearanceSeed ?? 7
    }

    private func name(of guest: PartyGuest) -> String {
        switch guest {
        case .outlet(let outlet): outlet
        case .contact(let id): state.networking.contact(id)?.name ?? "A guest"
        }
    }
}

/// Somebody standing in the room: the roster, the press, the address book,
/// all drawn from a seed the same way.
struct PartyPerson: Identifiable, Equatable {
    let id: UUID
    let name: String
    let seed: UInt64
    /// Press wear a badge; everybody else is just somebody at a party.
    let isPress: Bool
}

// MARK: - One venue

private struct PartyVenueRow: View {
    let venue: PartyVenue
    let quote: PartyQuote
    /// The house money line: "−$6,000 → $84,875 · runway 9 wk".
    let money: String
    let blocker: String?
    let selected: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(venue.displayName) · \(quote.cost.money)")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                Text(money)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(blocker == nil ? Theme.warning : .secondary)
                Text(PartyCopy.effectLine(quote))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(quote.desperate ? Theme.warning : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(venue.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let blocker {
                    Text(blocker)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.warning)
                }
            }
            Spacer(minLength: 0)
            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.accent)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(selected ? Theme.accent : .clear, lineWidth: 2)
        )
    }
}

// MARK: - The guest list

/// The names as chips, tapped on and off, capped at the venue's capacity.
private struct PartyGuestFlow: View {
    let pool: [PartyGuest]
    @Binding var guests: [PartyGuest]
    let limit: Int
    let name: (PartyGuest) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            ForEach(Array(pool.enumerated()), id: \.offset) { _, guest in
                let on = guests.contains(guest)
                let full = !on && guests.count >= limit
                Button {
                    Haptics.tap()
                    if on {
                        guests.removeAll { $0 == guest }
                    } else if !full {
                        guests.append(guest)
                    }
                } label: {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: on ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(on ? Theme.accent : .secondary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(name(guest))
                                .font(.system(.subheadline, design: .rounded).weight(.medium))
                            Text(kind(guest))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, Theme.Spacing.xs)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .opacity(full ? 0.45 : 1)
                }
                .buttonStyle(.pressableRow)
                .disabled(full)
                .accessibilityLabel("\(name(guest)), \(kind(guest))")
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }

    private func kind(_ guest: PartyGuest) -> String {
        switch guest {
        case .outlet: String(localized: "press", comment: "Launch party guest list: a review outlet")
        case .contact: String(localized: "from the address book", comment: "Launch party guest list: a contact")
        }
    }
}

// MARK: - The floor

/// The room: a backdrop that reads as the venue, a floor to stand on, the
/// founder in their corner, the roster across the middle and the guests
/// behind them. `NetworkingFloorView`'s composition, with the studio's own
/// people in it.
///
/// Deliberately not `private`, and free of navigation chrome, so a snapshot
/// can render the half of this screen worth looking at.
struct PartyFloorView: View {
    let venue: PartyVenue
    let team: [PartyPerson]
    let guests: [PartyPerson]
    let founderSeed: UInt64
    var reduceMotion = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                LinearGradient(colors: PartyCopy.backdrop(venue), startPoint: .top, endPoint: .bottom)

                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [.black.opacity(0.0), .black.opacity(0.35)],
                            startPoint: .top, endPoint: .bottom
                        ))
                        .frame(height: geometry.size.height * 0.55)
                        .overlay(alignment: .top) {
                            Rectangle().fill(.white.opacity(0.10)).frame(height: 1)
                        }
                }
                .allowsHitTesting(false)

                Text(venue.note)
                    .font(.caption.italic())
                    .foregroundStyle(.white.opacity(0.85))
                    .shadow(radius: 3)
                    .padding(Theme.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // The guests stand at the back of the room — always named,
                // because who came is the half of the list the player chose.
                ForEach(Array(guests.enumerated()), id: \.element.id) { index, person in
                    figure(person, height: guestHeight, named: true, badge: person.isPress)
                        .position(spot(
                            index, of: guests.count, in: geometry.size,
                            band: 0.18, depth: 0.22,
                            // The list is at most eight; four abreast keeps
                            // the back row one deep for the usual four
                            // outlets, so no tag lands on a neighbour.
                            columns: min(4, max(1, guests.count))
                        ))
                }

                // Your people, across the middle — the point of the picture.
                // A full studio is fifteen figures in a phone-width room, so
                // past six they lose their labels and shrink: a crowd reads
                // as a crowd, and a garage of three still reads as names.
                ForEach(Array(team.enumerated()), id: \.element.id) { index, person in
                    figure(person, height: teamHeight, named: team.count <= 6, badge: false)
                        .position(spot(index, of: team.count, in: geometry.size, band: 0.48, depth: 0.28))
                }

                VStack(spacing: 2) {
                    PixelFigure(
                        seed: founderSeed, isFounder: true, pose: .chat,
                        height: 72, reduceMotion: reduceMotion
                    )
                    tag("You")
                }
                .position(x: geometry.size.width * 0.13, y: geometry.size.height * 0.80)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(label)
                .accessibilitySortPriority(1)

                if team.isEmpty && guests.isEmpty {
                    Text("Just you, then.")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    /// "The rooftop: you, nine of the team and four guests."
    private var label: String {
        "\(venue.displayName): you, \(team.count) of the team and \(guests.count) "
            + "guest\(guests.count == 1 ? "" : "s")."
    }

    /// Figures shrink as the room fills, so a campus roster still fits the
    /// floor rather than standing on each other's heads.
    private var teamHeight: CGFloat {
        switch team.count {
        case ...4: 64
        case 5...8: 52
        default: 42
        }
    }

    private var guestHeight: CGFloat { guests.count > 4 ? 42 : 52 }

    private func figure(_ person: PartyPerson, height: CGFloat, named: Bool, badge: Bool) -> some View {
        VStack(spacing: 2) {
            PixelFigure(
                seed: person.seed, isFounder: false,
                pose: .chat, height: height, reduceMotion: reduceMotion
            )
            if named { tag(PartyCopy.shortName(person.name), press: badge) }
        }
        .accessibilityHidden(true)
    }

    private func tag(_ text: String, press: Bool = false) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                (press ? Theme.accent.opacity(0.75) : Color.black.opacity(0.45)),
                in: Capsule()
            )
    }

    /// The same seeded scatter the networking floor uses, over a band of the
    /// room: two to a row, jittered off the person's own seed so the same
    /// people stand in the same places every time the sheet opens.
    private func spot(
        _ index: Int, of count: Int, in size: CGSize,
        band: Double, depth: Double, columns fixed: Int? = nil
    ) -> CGPoint {
        let spread: Int = switch count {
        case ...1: 1
        case 2...4: 2
        case 5...8: 3
        default: 4
        }
        let columns = fixed ?? spread
        let column = index % columns
        let row = index / columns
        let rows = max(1, Int(ceil(Double(count) / Double(columns))))
        let seed = (index < 99 ? UInt64(index) : 0) &+ 17
        let jitterX = Double(seed &* 2_654_435_761 % 100) / 100 - 0.5
        let jitterY = Double(seed &* 40_503 % 100) / 100 - 0.5
        let x = 0.20 + (Double(column) + 0.5) / Double(columns) * 0.72 + jitterX * 0.05
        let y = band + (Double(row) + 0.5) / Double(rows) * depth + jitterY * 0.03
        return CGPoint(x: size.width * min(0.92, max(0.12, x)), y: size.height * min(0.80, max(0.14, y)))
    }
}

// MARK: end X4
