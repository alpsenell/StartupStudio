import Foundation
import TycoonContent

// Iteration 10 — M2. The pitch room.
//
// A term sheet, a contract offer, a launch-week interview and a quarterly
// board review are all, today, a card with two buttons on it. This file
// turns each of them into a short conversation in the networking floor's
// grammar — small talk, shop talk, listening, the pitch — and then prices
// the conversation back into the paperwork.
//
// The whole feature hangs off one invariant: **warmth zero is the game
// that shipped**. Every revision below is written as `term × (1 + warmth
// × span / 100)` (or `+ warmth × k`), so a run in which nobody ever sits
// down changes nothing at all — the accept and decline paths are the
// bytes they always were, and the pacing bots, which never pitch, never
// see this file run. Everything else here is guarded on
// `state.pitch != nil`, which is only ever non-nil because the player
// pressed *Talk first*.
//
// Types in this lane are prefixed `Pitch…` (rule 8).

// MARK: - Who is across the table

/// The four people the founder can sit down with.
public enum PitchCounterpart: String, Codable, Equatable, Sendable, CaseIterable {
    /// Opens from the term sheet on the table.
    case investor
    /// Opens from a contract offer.
    case client
    /// Opens in the week a product launches.
    case journalist
    /// Opens on a quarterly review with pressure on it.
    case board

    public var displayName: String {
        switch self {
        case .investor: "Investor"
        case .client: "Client"
        case .journalist: "Journalist"
        case .board: "The board"
        }
    }

    /// The button that opens the room, in the founder's words.
    public var invitation: String {
        switch self {
        case .investor: "Talk first"
        case .client: "Talk to them first"
        case .journalist: "Give the interview"
        case .board: "Talk to the board"
        }
    }

    /// One line under the button: what the conversation can move.
    public var stakesLine: String {
        switch self {
        case .investor: "Three exchanges to move the cheque, the equity and their patience."
        case .client: "Three exchanges to move the fee, the deadline and the bar."
        case .journalist: "Three exchanges to move the review and the front page."
        case .board: "Three exchanges to talk the pressure down. Or up."
        }
    }

    /// The founder attribute talking shop is graded on here. A journalist
    /// grades market sense, an investor and a board grade the numbers, a
    /// client grades whether you know how the work is done.
    public var gradedOn: FounderSkill {
        switch self {
        case .investor, .board: .finance
        case .client: .technical
        case .journalist: .marketKnowledge
        }
    }
}

// MARK: - The band

/// How the conversation went, in five steps. The band is a pure function
/// of warmth, and `even` is the shipped game.
public enum PitchBand: String, Codable, Equatable, Sendable, CaseIterable {
    case hostile, cool, even, warm, sold

    public var displayName: String {
        switch self {
        case .hostile: "Badly"
        case .cool: "Cool"
        case .even: "Even"
        case .warm: "Warm"
        case .sold: "Sold"
        }
    }

    /// Whether the room ended better than it started.
    public var isGood: Bool { self == .warm || self == .sold }
    public var isBad: Bool { self == .hostile || self == .cool }
}

// MARK: - The session

/// One conversation in progress. Cleared when it settles.
public struct PitchSession: Codable, Equatable, Sendable {
    public var counterpart: PitchCounterpart
    /// The contract offer or the product this is about. `nil` for the
    /// investor (there is only ever one term sheet) and for the board.
    public var subjectID: UUID?
    public var openedDay: Int
    /// Exchanges left tonight.
    public var exchangesLeft: Int
    /// Exchanges spent, so the sheet can count up as well as down.
    public var exchangesTaken: Int
    /// The hidden want's id in `Pitches.json`.
    public var wantID: String
    /// Set once the founder has listened.
    public var wantRevealed: Bool
    /// −100…100. Zero is the paper as written.
    public var warmth: Double
    /// The opener, then the last thing they said.
    public var lastLine: String
    /// Whether the last exchange landed. `nil` before the first one.
    public var lastLanded: Bool?

    public init(
        counterpart: PitchCounterpart,
        subjectID: UUID? = nil,
        openedDay: Int,
        exchangesLeft: Int,
        exchangesTaken: Int = 0,
        wantID: String,
        wantRevealed: Bool = false,
        warmth: Double = 0,
        lastLine: String = "",
        lastLanded: Bool? = nil
    ) {
        self.counterpart = counterpart
        self.subjectID = subjectID
        self.openedDay = openedDay
        self.exchangesLeft = exchangesLeft
        self.exchangesTaken = exchangesTaken
        self.wantID = wantID
        self.wantRevealed = wantRevealed
        self.warmth = warmth
        self.lastLine = lastLine
        self.lastLanded = lastLanded
    }

    public var band: PitchBand { PitchRoom.band(warmth) }
}

/// What one finished conversation left behind, for the room's history.
public struct PitchRecord: Codable, Equatable, Sendable {
    public var counterpart: PitchCounterpart
    public var day: Int
    public var band: PitchBand
    /// What it did to the paperwork, in one line.
    public var summary: String

    public init(counterpart: PitchCounterpart, day: Int, band: PitchBand, summary: String) {
        self.counterpart = counterpart
        self.day = day
        self.band = band
        self.summary = summary
    }
}

/// Everything the pitch room persists. `GameState.pitch` is `nil` until
/// the player opens their first room and goes back to `nil` when there is
/// nothing left to remember, so a save from a run that never pitched is
/// byte-for-byte the save it was.
public struct PitchState: Codable, Equatable, Sendable {
    /// The conversation on right now.
    public var session: PitchSession?
    /// Interviews whose notch has not landed yet: product id → −1 or +1.
    /// `PitchSystem.run` spends one the tick its product reaches the
    /// market and then forgets it.
    public var pressBumps: [String: Int]
    /// Subjects already talked to, so a term sheet cannot be worked twice.
    /// A key is `"<counterpart>:<subject>"`; encoded sorted.
    public var spent: [String]
    /// Finished conversations, newest last, capped at `maxLog`.
    public var log: [PitchRecord]

    static let maxLog = 12

    public init(
        session: PitchSession? = nil,
        pressBumps: [String: Int] = [:],
        spent: [String] = [],
        log: [PitchRecord] = []
    ) {
        self.session = session
        self.pressBumps = pressBumps
        self.spent = spent
        self.log = log
    }

    public static let empty = PitchState()

    /// Whether there is nothing here worth writing down. `PitchSystem`
    /// puts the whole slot back to `nil` when this is true.
    public var isEmpty: Bool {
        session == nil && pressBumps.isEmpty && spent.isEmpty && log.isEmpty
    }

    // Sorted `spent`, so two runs that talked to the same people in the
    // same order encode the same bytes whatever the insertion order was.
    private enum CodingKeys: String, CodingKey {
        case session, pressBumps, spent, log
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        session = try container.decodeIfPresent(PitchSession.self, forKey: .session)
        pressBumps = try container.decodeIfPresent([String: Int].self, forKey: .pressBumps) ?? [:]
        spent = try container.decodeIfPresent([String].self, forKey: .spent) ?? []
        log = try container.decodeIfPresent([PitchRecord].self, forKey: .log) ?? []
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(session, forKey: .session)
        if !pressBumps.isEmpty { try container.encode(pressBumps, forKey: .pressBumps) }
        if !spent.isEmpty { try container.encode(spent.sorted(), forKey: .spent) }
        if !log.isEmpty { try container.encode(log, forKey: .log) }
    }
}

// MARK: - The arithmetic

/// The room's pure half: what a warmth is worth, and what each set of
/// terms looks like after it.
///
/// Nothing here draws, reads the clock, or mutates. `PitchSystem` is the
/// only caller that changes anything, and the app calls exactly these
/// functions to put the revised numbers on the button *before* the player
/// commits — so the number they read is the number the engine writes.
public enum PitchRoom {
    /// Warmth is clamped to this either way.
    public static let warmthLimit: Double = 100

    /// The band a warmth falls into. Deliberately wide in the middle: a
    /// conversation has to actually go somewhere before the paper moves.
    public static func band(_ warmth: Double) -> PitchBand {
        switch warmth {
        case ..<(-55): .hostile
        case ..<(-15): .cool
        case ..<15: .even
        case ..<55: .warm
        default: .sold
        }
    }

    /// `1 + warmth/100 × span` — exactly 1 at warmth 0, whatever `span`
    /// is. Every multiplicative revision below goes through this, which
    /// is why a balance file that turns the spans up cannot disturb a run
    /// that never opened the room.
    public static func swing(_ warmth: Double, span: Double) -> Double {
        1 + (warmth / warmthLimit) * span
    }

    // MARK: The investor

    /// The term sheet after the conversation. A warm room buys a bigger
    /// cheque for a smaller slice and a longer leash; a cold one does the
    /// reverse. The valuation is re-derived from the two numbers so the
    /// sheet stays internally honest.
    public static func revised(
        _ offer: InvestmentOffer,
        warmth: Double,
        balance: BalanceConfig.PitchBalance
    ) -> InvestmentOffer {
        guard warmth != 0 else { return offer }
        var revised = offer
        revised.amount = max(1_000, Int(
            (Double(offer.amount) * swing(warmth, span: balance.investorAmountSpan)).rounded()
        ))
        // Equity moves the other way: warmth is the founder's leverage.
        revised.equity = max(0.5, min(60,
            offer.equity * swing(-warmth, span: balance.investorEquitySpan)
        ))
        revised.patienceWeeks = max(4, Int(
            (Double(offer.patienceWeeks) * swing(warmth, span: balance.investorPatienceSpan)).rounded()
        ))
        revised.valuation = revised.equity > 0
            ? max(revised.amount, Int((Double(revised.amount) / (revised.equity / 100)).rounded()))
            : offer.valuation
        return revised
    }

    // MARK: The client

    /// The job after the conversation: fee up, deadline out, and a client
    /// who has stopped demanding a crew they cannot afford.
    public static func revised(
        _ offer: ContractOffer,
        warmth: Double,
        balance: BalanceConfig.PitchBalance
    ) -> ContractOffer {
        guard warmth != 0 else { return offer }
        var revised = offer
        revised.payout = max(100, Int(
            (Double(offer.payout) * swing(warmth, span: balance.clientPayoutSpan)).rounded()
        ))
        revised.deadlineDays = max(3, Int(
            (Double(offer.deadlineDays) * swing(warmth, span: balance.clientDeadlineSpan)).rounded()
        ))
        // A client who likes you asks for less of a crew, not more.
        revised.requiredSkill = max(0,
            offer.requiredSkill * swing(-warmth, span: balance.clientSkillBarSpan)
        )
        // The penalty follows the fee, the way the offer generator sets it.
        revised.penalty = offer.payout > 0
            ? max(0, Int((Double(offer.penalty) * Double(revised.payout) / Double(offer.payout)).rounded()))
            : offer.penalty
        return revised
    }

    // MARK: The journalist

    /// Whether the interview earned a notch on the outlet's review, and
    /// which way. Needs a real result either way — a polite twenty
    /// minutes does not move a review.
    public static func pressNotch(
        _ warmth: Double, balance: BalanceConfig.PitchBalance
    ) -> Int {
        guard balance.pressNotchWarmth > 0 else { return 0 }
        if warmth >= balance.pressNotchWarmth { return 1 }
        if warmth <= -balance.pressNotchWarmth { return -1 }
        return 0
    }

    /// The hype the interview itself is worth, before the review lands.
    public static func hypeDelta(
        _ warmth: Double, balance: BalanceConfig.PitchBalance
    ) -> Double {
        warmth / warmthLimit * balance.pressHypeSwing
    }

    // MARK: The board

    /// Board pressure moved by the meeting. Negative is the founder
    /// talking it down.
    public static func pressureDelta(
        _ warmth: Double, balance: BalanceConfig.PitchBalance
    ) -> Double {
        -warmth / warmthLimit * balance.boardPressureSwing
    }

    // MARK: - Copy

    /// The line the room prints when it closes, from the catalog when it
    /// has one and from here when it does not.
    public static func closing(
        counterpart: PitchCounterpart,
        band: PitchBand,
        content: ContentCatalog
    ) -> String {
        if let line = content.pitchCounterpart(counterpart.rawValue)?.closings[band.rawValue] {
            return line
        }
        switch band {
        case .hostile: return "That went badly, and they'll remember it."
        case .cool: return "They're less keen than when you sat down."
        case .even: return "Nothing moved. The paper is the paper."
        case .warm: return "They came round, and it shows on the terms."
        case .sold: return "They're sold."
        }
    }

    /// What this band did, in the counterpart's own currency — the line
    /// on the closed room and in the journal.
    public static func summary(
        counterpart: PitchCounterpart,
        band: PitchBand,
        warmth: Double,
        balance: BalanceConfig.PitchBalance
    ) -> String {
        let percent = Int((abs(warmth) / warmthLimit * 100).rounded())
        switch counterpart {
        case .investor:
            if band == .even { return "The term sheet is unchanged." }
            return band.isGood
                ? "A bigger cheque for a smaller slice — about \(percent)% of the way there."
                : "They've marked the sheet down by about \(percent)%."
        case .client:
            if band == .even { return "The job is unchanged." }
            return band.isGood
                ? "More money and more time — about \(percent)% better."
                : "Less money and a tighter date — about \(percent)% worse."
        case .journalist:
            let notch = pressNotch(warmth, balance: balance)
            if notch > 0 { return "The review comes in a notch kinder." }
            if notch < 0 { return "The review comes in a notch harsher." }
            return band == .even ? "They'll write what they were going to write." : "A little buzz, no more."
        case .board:
            if band == .even { return "The board noted it and moved on." }
            return band.isGood
                ? "You talked the pressure down."
                : "You made it worse in the room."
        }
    }

    // MARK: - Reading the room

    /// What the exchange buttons say about themselves before they are
    /// pressed — rule 7, the consequence on the button.
    public static func read(
        _ topic: ConversationTopic,
        session: PitchSession,
        want: PitchWantDef?,
        state: GameState
    ) -> String {
        let favored = want?.favors == topic.rawValue
        switch topic {
        case .smallTalk:
            return favored && session.wantRevealed
                ? "Safe, and it happens to be what they want."
                : "Safe. A little warmth, never a mistake."
        case .listen:
            return session.wantRevealed
                ? "You already know what they want."
                : "Costs an exchange. Tells you what they're actually here for."
        case .shopTalk:
            let skill = Int(state.life.skills.value(for: session.counterpart.gradedOn).rounded())
            return "Graded on \(session.counterpart.gradedOn.displayName.lowercased()) — yours is \(skill)."
                + (favored && session.wantRevealed ? " It's what they want." : "")
        case .pitch:
            let base = "The swing. Twice the warmth, twice the damage."
            return favored && session.wantRevealed ? base + " Aimed right at them." : base
        }
    }
}

// MARK: - Is there anybody to talk to?

/// The two questions every entry point in the app asks — is there
/// somebody in that chair, and if not, why not — answered on the state
/// rather than inside `PitchSystem`, so a card can ask without reaching
/// into the engine's systems.
extension GameState {
    /// The subject a conversation with `counterpart` would be about. The
    /// outer optional is "is there anybody there"; the inner one is "does
    /// that conversation have a subject id" — the investor and the board
    /// do not.
    public func pitchSubject(
        for counterpart: PitchCounterpart,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> UUID?? {
        switch counterpart {
        case .investor:
            guard investors.pendingOffer != nil else { return nil }
            return .some(nil)
        case .client:
            guard let offer = contractOffers.first else { return nil }
            return .some(offer.id)
        case .journalist:
            guard let productID = interviewableProductID(balance: balance, content: content)
            else { return nil }
            return .some(productID)
        case .board:
            guard investors.boardPressure > 0, !investors.reviews.isEmpty else { return nil }
            return .some(nil)
        }
    }

    /// The build the press would want to talk about: the one closest to
    /// launch inside the launch week, or one that went out this week.
    public func interviewableProductID(
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> UUID? {
        if let eta = shipETAs(balance: balance, content: content)
            .first(where: { $0.daysAway <= GameState.daysPerWeek }) {
            return eta.productID
        }
        return products.first { product in
            if case .released(let info) = product.stage {
                return day - info.launchDay <= GameState.daysPerWeek && !info.offMarket
            }
            return false
        }?.id
    }

    /// Why the room will not open, in the founder's words — `nil` when it
    /// will. Rule 7: a refused action says why.
    public func pitchBlocker(
        for counterpart: PitchCounterpart,
        subjectID: UUID? = nil,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> String? {
        if life.isAway(day: day) { return "You're not in the building." }
        if pitch?.session != nil { return "You're already in a meeting." }
        guard let found = pitchSubject(for: counterpart, balance: balance, content: content)
        else {
            return switch counterpart {
            case .investor: "There's no term sheet on the table."
            case .client: "Nobody's offering work this week."
            case .journalist: "Nothing is close enough to launch to be worth an interview."
            case .board: "The board has nothing to review."
            }
        }
        if pitch?.spent.contains(PitchRoom.spentKey(counterpart, subjectID ?? found)) == true {
            return "You've already had that conversation."
        }
        return nil
    }
}

extension PitchRoom {
    /// `"investor:-"` / `"client:<uuid>"`: the thing a conversation was
    /// about, so it cannot be worked twice.
    public static func spentKey(_ counterpart: PitchCounterpart, _ subjectID: UUID?) -> String {
        "\(counterpart.rawValue):\(subjectID?.uuidString ?? "-")"
    }
}

extension FounderSkillSet {
    /// One attribute by case, so the pitch room can grade on a stored
    /// `FounderSkill` without a switch at every call site.
    func value(for skill: FounderSkill) -> Double {
        switch skill {
        case .conversation: conversation
        case .technical: technical
        case .marketKnowledge: marketKnowledge
        case .leadership: leadership
        case .finance: finance
        }
    }
}
