import Foundation
import TycoonContent

// Iteration 9 — L4 owns this file and may reshape it freely. Other lanes
// read `state.life.friends.friends` at most.

/// Who a friend is in the founder's life. Three people from before the
/// company, and three different things they can become.
public enum FriendArchetype: String, Codable, Equatable, Sendable, CaseIterable {
    /// The engineer you did all-nighters with in a computer lab. Hireable.
    case uniFriend
    /// The operator from the job before this one. Starts a company you can
    /// back out of your own wallet.
    case exColleague
    /// The civilian who has never once asked about your runway.
    case neighbour

    public var displayName: String {
        switch self {
        case .uniFriend: "The uni friend"
        case .exColleague: "The ex-colleague"
        case .neighbour: "The neighbour"
        }
    }

    /// One line about who they are, shown under their name.
    public var blurb: String {
        switch self {
        case .uniFriend: "Wrote your first compiler with you. Still ships."
        case .exColleague: "Ran ops at the job before this one."
        case .neighbour: "Two doors down. Has never asked about your runway."
        }
    }

    /// What they say about a buyout on the table, in their own register.
    public var buyoutOpinion: String {
        switch self {
        case .uniFriend:
            "Heard about the offer. You'd be selling the thing, not the money. Sleep on it twice."
        case .exColleague:
            "Take the meeting, read the earn-out clause, and don't sign anything with a two-year cliff in it."
        case .neighbour:
            "If it means you're home for dinner, I'm for it. That's my whole analysis."
        }
    }
}

/// A personal loan from a friend: no interest, no paperwork, and a slow
/// bleed on the friendship if it goes unpaid.
public struct FriendLoan: Codable, Equatable, Sendable {
    /// What is still owed.
    public var outstanding: Int
    /// What was borrowed originally.
    public var principal: Int
    public var borrowedDay: Int

    public init(outstanding: Int, principal: Int, borrowedDay: Int) {
        self.outstanding = outstanding
        self.principal = principal
        self.borrowedDay = borrowedDay
    }

    /// The day after which an unpaid loan starts costing the friendship.
    public func dueDay(_ tuning: FriendTuning = .standard) -> Int {
        borrowedDay + tuning.loanTermDays
    }
}

/// A named friend of the founder: somebody from before the company.
public struct Friend: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var appearanceSeed: UInt64
    /// Who they are in the founder's life.
    public var archetype: FriendArchetype
    /// 0...100, grown by the founder's own evenings, decayed by silence.
    public var bond: Double
    /// The day they were generated.
    public var metDay: Int
    /// The last day the founder called, saw them, or spent a weekend on
    /// them. Silence is measured from here.
    public var lastContactDay: Int
    /// The last day the founder gave them an evening (a call does not
    /// count) — the weekend picks whoever this is oldest for.
    public var lastSeenDay: Int
    /// The last day the founder phoned. Calls are once a week.
    public var lastCallDay: Int?
    /// Their company, once they have started one. Until then there is
    /// nothing to invest in.
    public var companyName: String?
    /// What that company is notionally worth. Zero until it exists.
    public var companyValuation: Int
    /// The day they moved abroad, if they did: the bond freezes, the
    /// thread stays.
    public var movedAwayDay: Int?
    /// The day they joined the payroll, if they did. Their `id` is the
    /// employee's id, so the roster and the friendship are the same person.
    public var hiredDay: Int?
    /// The money they lent the founder, if any.
    public var loan: FriendLoan?

    public init(
        id: UUID,
        name: String,
        appearanceSeed: UInt64,
        archetype: FriendArchetype,
        bond: Double,
        metDay: Int = 0,
        lastContactDay: Int = 0,
        lastSeenDay: Int = 0,
        lastCallDay: Int? = nil,
        companyName: String? = nil,
        companyValuation: Int = 0,
        movedAwayDay: Int? = nil,
        hiredDay: Int? = nil,
        loan: FriendLoan? = nil
    ) {
        self.id = id
        self.name = name
        self.appearanceSeed = appearanceSeed
        self.archetype = archetype
        self.bond = bond
        self.metDay = metDay
        self.lastContactDay = lastContactDay
        self.lastSeenDay = lastSeenDay
        self.lastCallDay = lastCallDay
        self.companyName = companyName
        self.companyValuation = companyValuation
        self.movedAwayDay = movedAwayDay
        self.hiredDay = hiredDay
        self.loan = loan
    }

    /// Their first name, which is what a text message uses.
    public var firstName: String {
        name.split(separator: " ").first.map(String.init) ?? name
    }

    /// Somebody who moved abroad is still a friend; they are just not
    /// coming over. Their bond stops moving in both directions.
    public var hasMovedAway: Bool { movedAwayDay != nil }

    /// Whether they are on the payroll now.
    public var isOnPayroll: Bool { hiredDay != nil }

    /// Where the friendship is, in the player's words.
    public var bondLabel: String {
        switch bond {
        case ..<20: "Barely in touch"
        case ..<40: "Drifting"
        case ..<60: "Still friends"
        case ..<80: "Close"
        default: "Family, basically"
        }
    }

    /// What they would bring to the payroll, derived from their own seed
    /// so the offer row and the person who walks in are the same.
    public var derivedSkills: SkillSet {
        func roll(_ shift: UInt64) -> Double { 30 + Double((appearanceSeed >> shift) % 40) }
        return switch archetype {
        case .uniFriend: SkillSet(coding: roll(4) + 25, design: roll(12), marketing: roll(20))
        case .exColleague: SkillSet(coding: roll(4), design: roll(12), marketing: roll(20) + 25)
        case .neighbour: SkillSet(coding: roll(4), design: roll(12), marketing: roll(20))
        }
    }

    /// The name of the company they start, derived rather than drawn: no
    /// stream moves, and the same beat names the same company every replay.
    public var derivedCompanyName: String {
        let firsts = ["Northline", "Ovenbird", "Palisade", "Quiet Harbour", "Ratchet", "Sundial"]
        let seconds = ["Systems", "Works", "Labs", "& Co", "Supply", "Robotics"]
        let first = firsts[Int(appearanceSeed % UInt64(firsts.count))]
        let second = seconds[Int((appearanceSeed >> 8) % UInt64(seconds.count))]
        return "\(first) \(second)"
    }

    /// What that company is notionally worth on the day it appears.
    public var derivedValuation: Int {
        60_000 + Int((appearanceSeed >> 16) % 340_000)
    }

    /// The most they would lend, at this bond. Nothing under the gate.
    public func loanCeiling(_ tuning: FriendTuning = .standard) -> Int {
        guard bond >= tuning.borrowBondGate else { return 0 }
        let ceiling = Int((bond * tuning.loanPerBondPoint).rounded())
        return max(0, ceiling - (loan?.outstanding ?? 0))
    }
}

/// Every number the friends feature uses. Kept here rather than in
/// `BalanceConfig` on purpose: nothing in this file is read by a run that
/// never engages with it, so there is no default for the pacing bots to
/// drift on.
public struct FriendTuning: Sendable {
    public var startingBond: [FriendArchetype: Double]
    /// Bond lost per day of silence, once the grace period is over.
    public var dailyDecay: Double
    /// Days of silence before the decay starts.
    public var silenceGraceDays: Int
    /// A phone call: free, weekly, small.
    public var callBond: Double
    public var callCooldownDays: Int
    /// An evening out.
    public var seeBond: Double
    public var seeCost: Int
    public var seeRelationships: Double
    public var seeMood: Double
    public var seeEnergy: Double
    /// The `.friends` weekend, spent on whoever you have seen least.
    public var weekendBond: Double
    /// The other two get a smaller share of the same weekend.
    public var weekendBystanderBond: Double
    /// Offer gates.
    public var hireBondGate: Double
    public var investBondGate: Double
    public var borrowBondGate: Double
    /// Dollars of credit per bond point.
    public var loanPerBondPoint: Double
    /// Weeks before an unpaid loan starts costing the friendship.
    public var loanTermDays: Int
    /// Extra bond lost per day once a loan is overdue.
    public var overdueDecay: Double
    /// The smallest cheque worth writing into a friend's company.
    public var minimumInvestment: Int
    /// The most of their company a friend will part with.
    public var maximumStakePercent: Double
    /// Bond a friend gains from being backed, hired, or repaid.
    public var investBond: Double
    public var hireBond: Double
    public var repaidBond: Double
    /// The bond at which a friend has an opinion about a buyout.
    public var buyoutOpinionBondGate: Double
    /// Below this, a friend stops texting on their own.
    public var quietBond: Double

    public static let standard = FriendTuning(
        startingBond: [.uniFriend: 60, .exColleague: 52, .neighbour: 45],
        dailyDecay: 0.12,
        silenceGraceDays: 7,
        callBond: 4,
        callCooldownDays: 7,
        seeBond: 9,
        seeCost: 60,
        seeRelationships: 6,
        seeMood: 4,
        seeEnergy: -5,
        weekendBond: 6,
        weekendBystanderBond: 1.5,
        hireBondGate: 70,
        investBondGate: 60,
        borrowBondGate: 75,
        loanPerBondPoint: 200,
        loanTermDays: 182,
        overdueDecay: 0.25,
        minimumInvestment: 2_000,
        maximumStakePercent: 25,
        investBond: 6,
        hireBond: 4,
        repaidBond: 5,
        buyoutOpinionBondGate: 70,
        quietBond: 25
    )
}

/// The founder's friends, and the bookkeeping that keeps their life beats
/// from firing twice.
public struct FriendsState: Codable, Equatable, Sendable {
    /// The three of them, **once the founder has done something about
    /// them**. Empty means "not materialised yet": the roster is still the
    /// pure function of the seed that `FriendRoster.derive` computes, so a
    /// run that never picks up the phone writes nothing to the wire and
    /// changes not one number. See `GameState.friendRoster(content:)`.
    public var friends: [Friend]
    /// The day the roster was written into state; `nil` until then.
    public var generatedDay: Int?
    /// Life-event id → the cooldown stamp the friend system has already
    /// reacted to. The narrative engine stamps a cooldown the moment a
    /// beat fires, so a changed stamp means "that happened today".
    public var seenEventStamps: [String: Int]
    /// The rival buyout offer the friends have already had an opinion
    /// about, so they only say it once per offer.
    public var opinedBuyoutDay: Int?

    public init(
        friends: [Friend] = [],
        generatedDay: Int? = nil,
        seenEventStamps: [String: Int] = [:],
        opinedBuyoutDay: Int? = nil
    ) {
        self.friends = friends
        self.generatedDay = generatedDay
        self.seenEventStamps = seenEventStamps
        self.opinedBuyoutDay = opinedBuyoutDay
    }

    public static let empty = FriendsState()

    public func friend(_ id: UUID) -> Friend? { friends.first { $0.id == id } }

    public func friend(_ archetype: FriendArchetype) -> Friend? {
        friends.first { $0.archetype == archetype }
    }

    /// The friend the founder has left alone longest — who the `.friends`
    /// weekend is really for. Somebody who moved abroad is skipped.
    public var mostNeglected: Friend? {
        friends.filter { !$0.hasMovedAway }
            .min { ($0.lastSeenDay, $0.id.uuidString) < ($1.lastSeenDay, $1.id.uuidString) }
    }

    /// The sum of every bond, which is what L2's life score reads.
    public var bondTotal: Double { friends.reduce(0) { $0 + $1.bond } }

    /// Everything the founder still owes.
    public var debtToFriends: Int { friends.reduce(0) { $0 + ($1.loan?.outstanding ?? 0) } }

    // Hand-written decode: a save written before any of these fields
    // existed reads as the default, and a save written before friends
    // existed at all reads as `.empty`.
    private enum CodingKeys: String, CodingKey {
        case friends, generatedDay, seenEventStamps, opinedBuyoutDay
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            friends: try container.decodeIfPresent([Friend].self, forKey: .friends) ?? [],
            generatedDay: try container.decodeIfPresent(Int.self, forKey: .generatedDay),
            seenEventStamps: try container.decodeIfPresent(
                [String: Int].self, forKey: .seenEventStamps
            ) ?? [:],
            opinedBuyoutDay: try container.decodeIfPresent(Int.self, forKey: .opinedBuyoutDay)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if !friends.isEmpty { try container.encode(friends, forKey: .friends) }
        try container.encodeIfPresent(generatedDay, forKey: .generatedDay)
        if !seenEventStamps.isEmpty {
            // Sorted by key: dictionaries encode in insertion order
            // otherwise, and identical states must stay byte-identical.
            try container.encode(
                seenEventStamps.sorted { $0.key < $1.key }
                    .reduce(into: [String: Int]()) { $0[$1.key] = $1.value },
                forKey: .seenEventStamps
            )
        }
        try container.encodeIfPresent(opinedBuyoutDay, forKey: .opinedBuyoutDay)
    }
}

// Hand-written decode for the same reason, plus room to add fields later.
extension Friend {
    private enum CodingKeys: String, CodingKey {
        case id, name, appearanceSeed, archetype, bond, metDay
        case lastContactDay, lastSeenDay, lastCallDay
        case companyName, companyValuation, movedAwayDay, hiredDay, loan
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            name: try container.decode(String.self, forKey: .name),
            appearanceSeed: try container.decode(UInt64.self, forKey: .appearanceSeed),
            archetype: try container.decodeIfPresent(FriendArchetype.self, forKey: .archetype)
                ?? .neighbour,
            bond: try container.decodeIfPresent(Double.self, forKey: .bond) ?? 0,
            metDay: try container.decodeIfPresent(Int.self, forKey: .metDay) ?? 0,
            lastContactDay: try container.decodeIfPresent(Int.self, forKey: .lastContactDay) ?? 0,
            lastSeenDay: try container.decodeIfPresent(Int.self, forKey: .lastSeenDay) ?? 0,
            lastCallDay: try container.decodeIfPresent(Int.self, forKey: .lastCallDay),
            companyName: try container.decodeIfPresent(String.self, forKey: .companyName),
            companyValuation: try container.decodeIfPresent(Int.self, forKey: .companyValuation) ?? 0,
            movedAwayDay: try container.decodeIfPresent(Int.self, forKey: .movedAwayDay),
            hiredDay: try container.decodeIfPresent(Int.self, forKey: .hiredDay),
            loan: try container.decodeIfPresent(FriendLoan.self, forKey: .loan)
        )
    }
}

// MARK: - The roster before anybody touches it

/// The three friends as a pure function of the run's seed.
///
/// Iteration 9's rule is that a feature the player never engages must not
/// change a single number — and that includes the bytes on the wire, which
/// `OriginTests` pins. So the roster is *derived*, not stored: until the
/// founder calls somebody, spends a weekend on them or takes one of the
/// three offers, `state.life.friends` stays `.empty` and encodes nothing.
/// `FriendSystem.materialise` writes it down the first time it matters,
/// and from then on the stored roster is the truth.
public enum FriendRoster {
    /// The day the friendships are dated from. They are people from before
    /// the company, so day one is when the run first sees them.
    public static let originDay = 1

    /// The roster at `day`, with the silence since day one already priced
    /// in — which is what makes an untouched friendship visibly fade in
    /// the UI without a byte of state behind it.
    public static func derive(
        seed: UInt64,
        names: NamePools,
        day: Int,
        tuning: FriendTuning = .standard
    ) -> [Friend] {
        // A private stream, derived from the seed the way `worldRNG` and
        // `socialRNG` are, so meeting your friends draws nothing from a
        // stream anything else reads.
        var rng = SeededRNG(seed: seed &* 0xB5AD_4ECE_DA1C_E2A9 &+ 4)
        let pool = names.friendNames.isEmpty ? names.firstNames : names.friendNames
        let lastNames = names.lastNames

        func pick(_ options: [String]) -> String {
            guard !options.isEmpty else { return "" }
            return options[rng.nextInt(in: 0...(options.count - 1))]
        }

        let silentDays = max(0, day - originDay - tuning.silenceGraceDays)
        var used: Set<String> = []
        var friends: [Friend] = []
        for archetype in FriendArchetype.allCases {
            var first = pick(pool)
            var attempts = 0
            while used.contains(first), attempts < 8 {
                first = pick(pool)
                attempts += 1
            }
            used.insert(first)
            let last = pick(lastNames)
            let full = last.isEmpty ? first : "\(first) \(last)"
            let start = tuning.startingBond[archetype] ?? 50
            friends.append(Friend(
                id: UUID(from: &rng),
                name: full.isEmpty ? archetype.displayName : full,
                appearanceSeed: rng.next(),
                archetype: archetype,
                bond: max(0, start - Double(silentDays) * tuning.dailyDecay),
                metDay: originDay,
                lastContactDay: originDay,
                lastSeenDay: originDay
            ))
        }
        return friends
    }
}

extension GameState {
    /// The founder's three friends: the stored roster once anything has
    /// happened to them, the derived one until then. Every surface reads
    /// this rather than `life.friends.friends`.
    public func friendRoster(content: ContentCatalog) -> [Friend] {
        life.friends.friends.isEmpty
            ? FriendRoster.derive(seed: seed, names: content.names, day: day)
            : life.friends.friends
    }

    /// One of them, by id, whichever roster is live.
    public func friend(_ id: UUID, content: ContentCatalog) -> Friend? {
        friendRoster(content: content).first { $0.id == id }
    }

    /// The numbers the friends feature runs on, so a card can quote a gate
    /// rather than copying it.
    public var friendTuning: FriendTuning { FriendSystem.tuning }

    // The engine's own refusal reasons, so the button and the reducer can
    // never disagree about a gate. `nil` means the action is open.

    public func friendCallBlocker(_ friendID: UUID, content: ContentCatalog) -> String? {
        FriendSystem.callBlocker(friendID: friendID, state: self, content: content)
    }

    public func friendEveningBlocker(
        _ friendID: UUID, balance: BalanceConfig, content: ContentCatalog
    ) -> String? {
        FriendSystem.seeBlocker(friendID: friendID, state: self, balance: balance, content: content)
    }

    public func friendHireBlocker(
        _ friendID: UUID, balance: BalanceConfig, content: ContentCatalog
    ) -> String? {
        FriendSystem.hireBlocker(friendID: friendID, state: self, balance: balance, content: content)
    }

    public func friendInvestBlocker(
        _ friendID: UUID, amount: Int, content: ContentCatalog
    ) -> String? {
        FriendSystem.investBlocker(friendID: friendID, amount: amount, state: self, content: content)
    }

    public func friendBorrowBlocker(
        _ friendID: UUID, amount: Int, content: ContentCatalog
    ) -> String? {
        FriendSystem.borrowBlocker(friendID: friendID, amount: amount, state: self, content: content)
    }

    public func friendRepayBlocker(
        _ friendID: UUID, amount: Int, content: ContentCatalog
    ) -> String? {
        FriendSystem.repayBlocker(friendID: friendID, amount: amount, state: self, content: content)
    }

    /// The last thing a friend said, for the card's one line.
    public func lastLine(from friendID: UUID) -> PhoneMessage? {
        life.phone.thread(with: .friend(friendID))?.messages.last
    }
}
