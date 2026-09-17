import SwiftUI
import TycoonContent
import TycoonEngine

// MARK: V1 (ux: Life folded, rooms dormant)

/// Iteration 14 — V1, C1. The five sections Life folds into, in the order
/// the founder's week runs: the week itself, the people in it, the money
/// and the home, the founder's own sheet, and the rooms.
///
/// Three open by default. A closed section is one line that says what is
/// inside it; the open or closed state is per install (`GameSettings`),
/// like tip dismissal, so nothing the player folded pops back open.
enum LifeSectionID: String, CaseIterable, Sendable {
    case thisWeek = "week"
    case people
    case moneyHome = "money"
    case you
    case more

    var title: String {
        switch self {
        case .thisWeek: "This week"
        case .people: "People"
        case .moneyHome: "Money and home"
        case .you: "You"
        case .more: "More of your life"
        }
    }

    var systemImage: String {
        switch self {
        case .thisWeek: "calendar"
        case .people: "person.2.fill"
        case .moneyHome: "house.fill"
        case .you: "person.fill"
        case .more: "square.grid.2x2.fill"
        }
    }

    /// The week, the people and the rooms are open on a fresh install;
    /// the wallet and the founder's sheet are one line each until asked.
    var opensByDefault: Bool {
        switch self {
        case .thisWeek, .people, .more: true
        case .moneyHome, .you: false
        }
    }
}

/// The per-install memory behind every fold on Life.
enum LifeFold {
    static func isOpen(_ id: String, default fallback: Bool) -> Bool {
        if let forced = DebugLaunch.lifeFolds { return forced }
        return GameSettings.lifeFoldIsOpen(id, default: fallback)
    }

    static func remember(_ id: String, isOpen: Bool) {
        GameSettings.setLifeFold(id, isOpen: isOpen)
    }
}

extension View {
    /// Keeps a view in the hierarchy — its `.task`s, sheets and one-shot
    /// launch routes — without drawing it or giving it any height. A card
    /// folded away still runs the debug hooks and landings it owns.
    func lifeHook() -> some View {
        frame(height: 0)
            .clipped()
            .hidden()
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }
}

// MARK: - The section

/// One of Life's five sections: a header that folds it, and the cards it
/// expands to. Closed, the header is a single block carrying the summary
/// line ("People · Priya 64 ♥ · 2 kids · 3 asking").
///
/// `hooks` is drawn, invisibly, while the section is closed: the cards
/// that own a debug hook or a launch landing keep it.
struct LifeSection<Content: View, Hooks: View>: View {
    let id: LifeSectionID
    let summary: String
    let badge: Int
    /// Open for this launch whatever the install remembers, and not
    /// remembered: a launch route that lands inside the section.
    let forcedOpen: Bool
    private let content: Content
    private let hooks: Hooks

    @State private var isOpen: Bool

    init(
        _ id: LifeSectionID,
        summary: String,
        badge: Int = 0,
        forcedOpen: Bool = false,
        @ViewBuilder content: () -> Content,
        @ViewBuilder hooks: () -> Hooks
    ) {
        self.id = id
        self.summary = summary
        self.badge = badge
        self.forcedOpen = forcedOpen
        self.content = content()
        self.hooks = hooks()
        _isOpen = State(initialValue: LifeFold.isOpen(id.rawValue, default: id.opensByDefault))
    }

    private var showsContent: Bool { isOpen || forcedOpen }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            header
            if showsContent {
                content
            }
        }
        .background {
            if !showsContent {
                hooks.lifeHook()
            }
        }
    }

    private var header: some View {
        Button {
            Haptics.tap()
            let next = !showsContent
            withAnimation(.snappy(duration: 0.25)) { isOpen = next }
            LifeFold.remember(id.rawValue, isOpen: next)
        } label: {
            HStack(alignment: .center, spacing: Theme.Spacing.sm) {
                Image(systemName: id.systemImage)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 3) {
                    Text(id.title)
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .textCase(.uppercase)
                        .kerning(0.6)
                        .foregroundStyle(.secondary)
                    if !showsContent {
                        Text(summary)
                            .font(.system(.subheadline, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: Theme.Spacing.sm)
                if badge > 0 {
                    LifeBadge(count: badge)
                }
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.accent)
                    .rotationEffect(.degrees(showsContent ? 0 : -90))
            }
            .padding(.horizontal, showsContent ? Theme.Spacing.xs : Theme.Spacing.lg)
            .padding(.vertical, showsContent ? 0 : Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                showsContent ? Color.clear : Theme.cardBackground,
                in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressableRow)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityLabel(showsContent ? id.title : "\(id.title). \(summary)")
        .accessibilityValue(showsContent ? "Open" : "Folded")
        .accessibilityHint(showsContent ? "Folds the section" : "Opens the section")
    }
}

extension LifeSection where Hooks == EmptyView {
    init(
        _ id: LifeSectionID,
        summary: String,
        badge: Int = 0,
        forcedOpen: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.init(id, summary: summary, badge: badge, forcedOpen: forcedOpen, content: content) {
            EmptyView()
        }
    }
}

/// The count on a section or a row: how many things in it wait on you.
struct LifeBadge: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(Theme.Typography.number(.caption))
            .foregroundStyle(Theme.ink(on: Theme.warning))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Theme.warning, in: Capsule())
            .accessibilityLabel("\(count) waiting")
    }
}

// MARK: - A row

/// One line of a section: a card at the `.row` weight (title, one number,
/// a chevron) that pushes its page or unfolds its card, or at `.quiet`
/// for a room nobody has opened. Lit — a dot and the warning tint — when
/// something in it waits on the founder.
struct LifeRow: View {
    enum Accessory: Equatable {
        /// Pushes a page.
        case push
        /// Unfolds the card under the row.
        case fold(isOpen: Bool)
    }

    let title: String
    let systemImage: String
    let value: String
    var isLit = false
    var weight: CardWeight = .row
    var accessory: Accessory = .push
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            CardView(title, systemImage: systemImage, weight: weight) {
                HStack(spacing: Theme.Spacing.sm) {
                    if isLit {
                        Circle()
                            .fill(Theme.warning)
                            .frame(width: 8, height: 8)
                            .accessibilityHidden(true)
                    }
                    Text(value)
                        .font(weight == .quiet
                            ? .footnote
                            : .system(.subheadline, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(isLit ? Theme.warning : weight == .quiet ? Color.secondary : Color.primary)
                        .lineLimit(1)
                    Spacer(minLength: Theme.Spacing.sm)
                    chevron
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressableRow)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value)")
        .accessibilityValue(isLit ? "Waiting on you" : "")
        .accessibilityHint(hint)
    }

    @ViewBuilder
    private var chevron: some View {
        switch accessory {
        case .push:
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.accent)
        case .fold(let isOpen):
            Image(systemName: "chevron.down")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.accent)
                .rotationEffect(.degrees(isOpen ? 0 : -90))
        }
    }

    private var hint: String {
        switch accessory {
        case .push: "Opens the page"
        case .fold(let isOpen): isOpen ? "Folds the card" : "Unfolds the card"
        }
    }
}

// MARK: - The rooms

/// Iteration 14 — V1, C1 and C2. The seven rooms iterations 9 and 11
/// built on Life. Each is dormant — one quiet row under "Other rooms" —
/// until its state is non-empty or something opened it (a door, an event,
/// a case, a first post). Open, it is a row with its one number that
/// unfolds to its card, lit while something in it waits on you.
///
/// The cards' own `body` guards read `isOpen`, so a card and its row can
/// never disagree about whether the room exists yet.
enum LifeRoom: String, CaseIterable, Identifiable, Sendable {
    case crime
    case assets
    case fame
    case familyDrama = "family"
    case sideProject = "side"
    case sabbatical
    case lifeScore = "score"

    var id: String { rawValue }

    /// The card's own title, so the row and the card it unfolds match.
    var title: String {
        switch self {
        case .crime: "The other ledger"
        case .assets: "What you own"
        case .fame: "The feed"
        case .familyDrama: "The rest of the family"
        case .sideProject: "On the side"
        case .sabbatical: "Stepping away"
        case .lifeScore: "Your life"
        }
    }

    var systemImage: String {
        switch self {
        case .crime: "scalemass.fill"
        case .assets: "key.fill"
        case .fame: "at"
        case .familyDrama: "person.2.badge.gearshape.fill"
        case .sideProject: "sparkles"
        case .sabbatical: "airplane.departure"
        case .lifeScore: "heart.text.square.fill"
        }
    }

    /// Where the room's page is, for the quiet row of a room nobody has
    /// opened yet: the same page the card's own button pushes.
    var destination: LifeScreen.LifeDestination {
        switch self {
        case .crime: .crime
        case .assets: .assets
        case .fame: .feed
        case .familyDrama: .family
        case .sideProject: .sideProject
        case .sabbatical: .sabbatical
        case .lifeScore: .lifeScore
        }
    }

    /// Whether the room has anything in it yet. State reads only; the
    /// engine writes none of this on a run that never engages, which is
    /// what keeps a dormant room dormant.
    func isOpen(in state: GameState, balance: BalanceConfig) -> Bool {
        switch self {
        case .crime:
            let crime = state.crime
            return !crime.record.isEmpty || !crime.cases.isEmpty || crime.hearing != nil
                || crime.sentenceUntilDay != nil || crime.notoriety > 0
        case .assets:
            return state.assets.isEngaged
        case .fame:
            let fame = state.fame
            return !fame.posts.isEmpty || fame.followers > 0 || fame.beef != nil
                || fame.cancellation != nil || !fame.perks.isEmpty
        case .familyDrama:
            let drama = state.familyDrama
            return drama.openedDay != nil || drama.isConfrontationOpen || drama.isFuneralOpen
                || drama.pendingAsk != nil || drama.settlement != nil
        case .sideProject:
            return state.life.sideProject != nil
        case .sabbatical:
            return state.life.sabbatical != nil
        case .lifeScore:
            // The score is always computable; it becomes a room once it
            // can be a way out — the day walking away is on the table.
            return state.day >= balance.lifeScore.walkAwayMinDay || state.canWalkAway(balance: balance)
        }
    }

    /// Something in the room waits on the founder: the row is lit.
    func isWaiting(in state: GameState, balance: BalanceConfig) -> Bool {
        switch self {
        case .crime: state.crime.pendingCase != nil || state.crime.hearing != nil
        case .assets: false
        case .fame: state.fame.cancellation != nil || state.fame.beef != nil
        case .familyDrama:
            state.familyDrama.isConfrontationOpen || state.familyDrama.isFuneralOpen
                || state.familyDrama.pendingAsk != nil
        case .sideProject: false
        case .sabbatical: state.life.sabbatical?.isActive == true
        case .lifeScore: state.canWalkAway(balance: balance)
        }
    }

    /// The open row's one line: its one number, or what is waiting.
    func line(in state: GameState, balance: BalanceConfig, content: ContentCatalog) -> String {
        switch self {
        case .crime:
            let crime = state.crime
            if crime.hearing != nil { return "In the courtroom" }
            if crime.pendingCase != nil { return "A case is waiting to be heard" }
            return "\(crime.record.count) on the record · heat \(Int(crime.notoriety.rounded()))"
        case .assets:
            let owned = state.assets.owned.count
            if owned == 0 { return "Nothing owned yet" }
            return "\(owned) owned · \(state.assetResaleValue(balance: balance).money)"
        case .fame:
            let level = Fame.level(state.fame.fame, balance: balance.fame)
            return "\(FeedFormat.count(state.fame.followers)) followers · \(level.displayName)"
        case .familyDrama:
            let drama = state.familyDrama
            if drama.isConfrontationOpen { return "They know" }
            if drama.isFuneralOpen { return "The funeral is Thursday" }
            if drama.pendingAsk != nil {
                return "\(state.familyRelativeName(.sibling, content: content)) is waiting on an answer"
            }
            if drama.settlement != nil { return "After the divorce" }
            return "Parents, a sibling, opinions"
        case .sideProject:
            guard let project = state.life.sideProject else { return "" }
            if let track = project.track {
                let name = SideProjectTrack(rawValue: track)?.displayName ?? track
                return "\(name) · chapter \(project.chapter + 1)"
            }
            let done = project.completedTracks.count
            return "\(done) finished"
        case .sabbatical:
            guard let sabbatical = state.life.sabbatical else { return "" }
            if sabbatical.isActive { return "Away until day \(sabbatical.untilDay)" }
            return "Back since day \(sabbatical.endedDay ?? sabbatical.untilDay)"
        case .lifeScore:
            let score = LifeScore.score(state, balance: balance)
            return state.canWalkAway(balance: balance)
                ? "Life \(score) · you could walk away"
                : "Life \(score)"
        }
    }

    /// The quiet row of a room nobody has opened: one line of the card's
    /// old invitation.
    var dormantLine: String {
        switch self {
        case .crime: "Six things you should not do"
        case .assets: "A whole column with nothing in it"
        case .fame: "An account with no posts on it"
        case .familyDrama: "The people you did not choose"
        case .sideProject: "Something that is not the company"
        case .sabbatical: "A month away, if you trust somebody"
        case .lifeScore: "What it all adds up to, later"
        }
    }
}

/// What a dormant room's card draws: nothing, with no height — but a view,
/// so the modifiers the card carries (`.task`, `.sheet`) stay attached.
struct LifeRoomDormant: View {
    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
    }
}

/// A row that unfolds to the card(s) under it, remembered per install
/// under `foldID`. With `keepsHook`, the folded card is still in the
/// hierarchy (`lifeHook`), so the debug hooks it owns keep running.
struct LifeUnfold<Card: View>: View {
    let foldID: String
    let title: String
    let systemImage: String
    let value: String
    let isLit: Bool
    let keepsHook: Bool
    private let card: Card

    @State private var isOpen: Bool

    init(
        _ foldID: String,
        title: String,
        systemImage: String,
        value: String,
        isLit: Bool = false,
        keepsHook: Bool = false,
        @ViewBuilder card: () -> Card
    ) {
        self.foldID = foldID
        self.title = title
        self.systemImage = systemImage
        self.value = value
        self.isLit = isLit
        self.keepsHook = keepsHook
        self.card = card()
        _isOpen = State(initialValue: LifeFold.isOpen(foldID, default: false))
    }

    var body: some View {
        VStack(spacing: 0) {
            LifeRow(
                title: title,
                systemImage: systemImage,
                value: value,
                isLit: isLit,
                accessory: .fold(isOpen: isOpen)
            ) {
                let next = !isOpen
                withAnimation(.snappy(duration: 0.25)) { isOpen = next }
                LifeFold.remember(foldID, isOpen: next)
            }
            if isOpen {
                card.padding(.top, Theme.Spacing.sm)
            }
        }
        .background {
            if keepsHook && !isOpen {
                card.lifeHook()
            }
        }
    }
}

/// An open room: its row, and its card unfolded under it. Folded, the card
/// is still in the hierarchy, so the hooks it owns keep running.
struct LifeRoomBlock<Card: View>: View {
    let room: LifeRoom
    let engine: GameEngine
    private let card: Card

    init(room: LifeRoom, engine: GameEngine, @ViewBuilder card: () -> Card) {
        self.room = room
        self.engine = engine
        self.card = card()
    }

    var body: some View {
        let state = engine.state
        LifeUnfold(
            "room." + room.rawValue,
            title: room.title,
            systemImage: room.systemImage,
            value: room.line(in: state, balance: engine.balance, content: engine.content),
            isLit: room.isWaiting(in: state, balance: engine.balance),
            keepsHook: true
        ) { card }
    }
}

/// The rooms nobody has opened, as one quiet row that unfolds to a quiet
/// row each. A row pushes the room's page, which is where it starts.
struct LifeOtherRooms<Hooks: View>: View {
    let rooms: [LifeRoom]
    let onOpen: (LifeRoom) -> Void
    private let hooks: Hooks

    @State private var isOpen: Bool

    init(rooms: [LifeRoom], onOpen: @escaping (LifeRoom) -> Void, @ViewBuilder hooks: () -> Hooks) {
        self.rooms = rooms
        self.onOpen = onOpen
        self.hooks = hooks()
        _isOpen = State(initialValue: LifeFold.isOpen("rooms.other", default: false))
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            LifeRow(
                title: "Other rooms",
                systemImage: "door.left.hand.closed",
                value: "\(rooms.count) not opened yet",
                weight: .quiet,
                accessory: .fold(isOpen: isOpen)
            ) {
                let next = !isOpen
                withAnimation(.snappy(duration: 0.25)) { isOpen = next }
                LifeFold.remember("rooms.other", isOpen: next)
            }
            if isOpen {
                ForEach(rooms) { room in
                    LifeRow(
                        title: room.title,
                        systemImage: room.systemImage,
                        value: room.dormantLine,
                        weight: .quiet
                    ) { onOpen(room) }
                }
            }
        }
        .background { hooks.lifeHook() }
    }
}

// MARK: - The people's pages

/// The pages People's rows push for the three people who never had a
/// page of their own: each is the card it always was, on its own.
enum LifeCardPage: String, Hashable, Sendable {
    case partner
    case family
    case networking
}

struct LifeCardPageView: View {
    let engine: GameEngine
    let page: LifeCardPage

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                switch page {
                case .partner: PartnerCard(engine: engine)
                case .family: FamilyCard(engine: engine)
                case .networking: NetworkingCard(engine: engine)
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.screenBackground)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var title: String {
        switch page {
        case .partner: engine.state.life.family.partnerName ?? "Your partner"
        case .family: "Family"
        case .networking: "Networking"
        }
    }
}

// MARK: - The summary lines

/// What a folded section says about itself, in one line. Main-actor, as
/// the engine it reads is.
@MainActor
enum LifeSummary {
    /// Phone threads waiting on an answer — the same count as the tab's
    /// badge (`TabBadge.life`).
    static func asking(_ state: GameState, content: ContentCatalog) -> Int {
        state.life.phone.threads.filter {
            PhoneReply.isWaiting($0.counterpart, in: state, content: content)
        }.count
    }

    static func output(_ state: GameState, balance: BalanceConfig) -> String {
        "×" + state.founderOutputMultiplier(balance: balance)
            .formatted(.number.precision(.fractionLength(2)).locale(Theme.gameLocale))
    }

    /// "3 evenings left · Rent tomorrow · output ×0.95"
    static func thisWeek(_ engine: GameEngine) -> String {
        let state = engine.state
        var parts: [String] = []
        if let evenings = state.eveningsLeftThisWeek(engine.balance) {
            parts.append("\(evenings) evening\(evenings == 1 ? "" : "s") left")
        }
        if let next = Agenda.items(in: state, balance: engine.balance, content: engine.content).first {
            parts.append("\(next.title) \(AgendaCard.whenLabel(next.day - state.day))")
        }
        parts.append("output " + output(state, balance: engine.balance))
        return parts.joined(separator: " · ")
    }

    /// "Priya 64 ♥ · 2 kids · 3 asking"
    static func people(_ engine: GameEngine) -> String {
        let state = engine.state
        let family = state.life.family
        var parts: [String] = []
        if family.stage != .single {
            parts.append("\(family.partnerName ?? "Partner") \(Int(family.affection.rounded())) ♥")
        }
        let kids = family.children.count
        if kids > 0 { parts.append("\(kids) kid\(kids == 1 ? "" : "s")") }
        let asking = asking(state, content: engine.content)
        if asking > 0 { parts.append("\(asking) asking") }
        if parts.isEmpty {
            let friends = state.friendRoster(content: engine.content).count
            parts.append("\(friends) friend\(friends == 1 ? "" : "s")")
            parts.append("\(state.networking.contacts.count(where: \.isOpen)) contacts")
        }
        return parts.joined(separator: " · ")
    }

    /// "Wallet $2,400 · rent $300 in 3d"
    static func money(_ engine: GameEngine) -> String {
        let state = engine.state
        let rent = homeWeeklyRent(state.life.home, balance: engine.balance)
        // Rent leaves with the week's close, on the day `day % 7 == 0`.
        let days = GameState.daysPerWeek - state.day % GameState.daysPerWeek
        return "Wallet \(state.life.wallet.money) · rent \(rent.money) in \(days)d"
    }

    /// "Output ×0.88 · energy 64"
    static func you(_ engine: GameEngine) -> String {
        let state = engine.state
        return "Output \(output(state, balance: engine.balance)) · energy \(Int(state.life.meters.energy.rounded()))"
    }

    /// "1 waiting · 3 open" / "2 open · 5 not opened yet"
    static func more(open: Int, waiting: Int, dormant: Int, doors: Int) -> String {
        var parts: [String] = []
        if doors > 0 { parts.append("\(doors) at the door") }
        if waiting > 0 { parts.append("\(waiting) waiting") }
        if open > 0 { parts.append("\(open) room\(open == 1 ? "" : "s") open") }
        if dormant > 0 { parts.append("\(dormant) not opened yet") }
        return parts.joined(separator: " · ")
    }
}

// MARK: end V1
