import Foundation
import TycoonContent

/// Iteration 9 — L4. Three people from before the company: they have names
/// and faces from day one, they drift when the founder stops calling, they
/// get married and start companies and move abroad, and every one of those
/// is a text message rather than a number.
///
/// **Neutral by construction.** Nothing here touches the company. Until
/// the founder does something about one of them the roster is *derived*
/// from the seed (`FriendRoster.derive`) and `state.life.friends` stays
/// `.empty`: a run that never engages writes not one byte, draws from no
/// shared stream, and never sees the four `friend_*` life events, which
/// are gated on the flag `materialise` raises. That is iteration 9's
/// identity rule taken literally.
///
/// **Determinism.** The roster comes from a private stream derived from
/// `state.seed` the way `worldRNG` and `socialRNG` are — *not* by drawing
/// from `socialRNG`, because generating on day 1 would shift that shared
/// stream and move the pinned balance. Nothing else here draws at all: a
/// friend's company and its valuation are derived from their
/// `appearanceSeed`.
enum FriendSystem {
    static let tuning = FriendTuning.standard

    /// Raised the first time the founder does something about a friend.
    /// The four appended `friend_*` life events require it, so they only
    /// enter the roll for a run that has friends in it.
    static let engagedFlag = "friends_in_your_life"

    /// The life events that are about one of these three people. The
    /// narrative engine stamps a cooldown the moment a beat fires, so a
    /// changed stamp is how this system learns it happened without
    /// reaching into `NarrativeSystem`.
    static let hookedEventIDs: [String] = [
        "friends_wedding", "friend_moves_away", "friend_startup_advisor",
        "burnout_friend", "holiday_alone", "old_friend_visits",
        "friend_wedding_invite", "friend_started_something",
        "friend_hit_the_wall", "friend_leaving_town",
    ]

    // MARK: - Daily

    static func run(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        // Nothing has happened to anybody yet: the roster is still a pure
        // function of the seed and there is nothing to keep.
        guard !state.life.friends.friends.isEmpty else { return [] }
        decay(&state)
        reactToLifeEvents(&state)
        buyoutOpinion(&state)
        return []
    }

    /// Writes the derived roster into state, once, the first time the
    /// founder does something that has to be remembered.
    @discardableResult
    static func materialise(_ state: inout GameState, _ content: ContentCatalog) -> Bool {
        guard state.life.friends.friends.isEmpty else { return false }
        state.life.friends.friends = FriendRoster.derive(
            seed: state.seed, names: content.names, day: state.day
        )
        state.life.friends.generatedDay = state.day
        state.narrative.flags.insert(engagedFlag)
        // A run that is well underway when it first calls somebody already
        // has cooldowns on the friend-shaped beats; take them as read so
        // nothing replays on the day the roster lands.
        for eventID in hookedEventIDs {
            if let stamp = state.narrative.cooldowns[eventID] {
                state.life.friends.seenEventStamps[eventID] = stamp
            }
        }
        return true
    }

    /// Silence costs. A friend who moved abroad is frozen: the distance is
    /// the story, not a slow fade.
    private static func decay(_ state: inout GameState) {
        let day = state.day
        for index in state.life.friends.friends.indices {
            var friend = state.life.friends.friends[index]
            guard !friend.hasMovedAway, !friend.isOnPayroll else { continue }
            let silent = day - friend.lastContactDay
            var loss = silent > tuning.silenceGraceDays ? tuning.dailyDecay : 0
            if let loan = friend.loan, loan.outstanding > 0, day > loan.dueDay(tuning) {
                loss += tuning.overdueDecay
            }
            guard loss > 0 else { continue }
            let before = friend.bond
            friend.bond = max(0, friend.bond - loss)
            state.life.friends.friends[index] = friend
            // The one line a fading friendship gets: they stop texting.
            if before >= tuning.quietBond, friend.bond < tuning.quietBond {
                state.life.phone.post(goneQuietLine(friend), from: .friend(friend.id), day: day)
            }
        }
    }

    private static func goneQuietLine(_ friend: Friend) -> String {
        switch friend.archetype {
        case .uniFriend: "Not chasing you any more. You know where I am when the company lets you out."
        case .exColleague: "I'll stop sending these. Good luck with it, genuinely."
        case .neighbour: "Waved at you through the window this morning. You didn't see me. That's fine."
        }
    }

    // MARK: - Life beats

    /// The friend-shaped life events, given a name. The narrative engine
    /// owns the roll and the meters; this only decides *who* it was about,
    /// moves their bond and puts it in their thread.
    private static func reactToLifeEvents(_ state: inout GameState) {
        for eventID in hookedEventIDs {
            guard let stamp = state.narrative.cooldowns[eventID] else { continue }
            if state.life.friends.seenEventStamps[eventID] == stamp { continue }
            state.life.friends.seenEventStamps[eventID] = stamp
            apply(beat: eventID, state: &state)
        }
    }

    /// Which friend a beat is about, and what it does to them.
    private static func apply(beat: String, state: inout GameState) {
        let day = state.day
        switch beat {
        case "friends_wedding", "friend_wedding_invite":
            guard let friend = target(.neighbour, or: .uniFriend, state) else { return }
            bump(friend.id, by: 5, contact: true, seen: true, state: &state)
            post(friend.id,
                 "That was a good night. You were the only one who danced. Thank you for coming.",
                 day: day, state: &state)

        case "friend_startup_advisor", "friend_started_something":
            guard var friend = target(.exColleague, or: .uniFriend, state) else { return }
            if friend.companyName == nil {
                friend.companyName = friend.derivedCompanyName
                friend.companyValuation = friend.derivedValuation
                replace(friend, in: &state)
            }
            bump(friend.id, by: 3, contact: true, seen: false, state: &state)
            post(friend.id,
                 "It's real now — \(friend.companyName ?? "the thing") has three customers and a bank account. If you ever want in, say the word.",
                 day: day, state: &state)

        case "burnout_friend", "friend_hit_the_wall":
            guard let friend = target(.uniFriend, or: .exColleague, state) else { return }
            bump(friend.id, by: 2, contact: true, seen: false, state: &state)
            post(friend.id,
                 "Sorry about last night. I know how that sounded. I'm going to sleep for a week.",
                 day: day, state: &state)

        case "friend_moves_away", "friend_leaving_town":
            guard var friend = movable(state) else { return }
            friend.movedAwayDay = day
            replace(friend, in: &state)
            post(friend.id,
                 "Flight's Thursday. I'm not going to pretend a text is the same thing.",
                 day: day, state: &state)

        case "old_friend_visits":
            guard let friend = mostNeglected(state) else { return }
            bump(friend.id, by: 6, contact: true, seen: true, state: &state)
            post(friend.id, "3am. Worth it. Next one's at mine.", day: day, state: &state)

        case "holiday_alone":
            // The lonely holiday now names who is not there.
            guard let friend = mostNeglected(state) ?? state.life.friends.friends.first else { return }
            post(friend.id, lonelyLine(friend), day: day, state: &state)

        default:
            break
        }
    }

    private static func lonelyLine(_ friend: Friend) -> String {
        friend.hasMovedAway
            ? "Wrong time zone for a call. Photo attached — pretend you're here."
            : "We're all at my sister's. There's a chair with your name on it if you ever answer these."
    }

    private static func mostNeglected(_ state: GameState) -> Friend? {
        state.life.friends.mostNeglected
    }

    /// The friend a "moving abroad" beat is about: whoever is still here,
    /// weakest bond first — the one you were already losing.
    private static func movable(_ state: GameState) -> Friend? {
        state.life.friends.friends
            .filter { !$0.hasMovedAway && !$0.isOnPayroll }
            .min { ($0.bond, $0.id.uuidString) < ($1.bond, $1.id.uuidString) }
    }

    private static func target(
        _ preferred: FriendArchetype,
        or fallback: FriendArchetype,
        _ state: GameState
    ) -> Friend? {
        let here = state.life.friends.friends.filter { !$0.hasMovedAway && !$0.isOnPayroll }
        return here.first { $0.archetype == preferred }
            ?? here.first { $0.archetype == fallback }
            ?? here.first
    }

    // MARK: - The buyout

    /// A friend who is close enough has an opinion about the offer on the
    /// table. Text only — no number in the game moves because of it.
    private static func buyoutOpinion(_ state: inout GameState) {
        guard let offer = state.rivals.pendingBuyout else {
            state.life.friends.opinedBuyoutDay = nil
            return
        }
        guard state.life.friends.opinedBuyoutDay != offer.respondByDay else { return }
        let close = state.life.friends.friends
            .filter { $0.bond >= tuning.buyoutOpinionBondGate && !$0.isOnPayroll && !$0.hasMovedAway }
            .sorted { ($0.bond, $0.id.uuidString) > ($1.bond, $1.id.uuidString) }
        guard let friend = close.first else { return }
        state.life.friends.opinedBuyoutDay = offer.respondByDay
        state.life.phone.post(
            friend.archetype.buyoutOpinion, from: .friend(friend.id), day: state.day
        )
    }

    // MARK: - The weekend

    /// The `.friends` weekend, resolved by `LifeSystem`: it goes to
    /// whoever the founder has seen least, and the other two hear about
    /// it. No company effect — this is the founder's own Saturday.
    ///
    /// It does *not* materialise the roster on its own: the pacing bots
    /// plan a friends weekend every month while the founder is single, and
    /// a weekend that wrote three people into state would move the shipped
    /// balance for runs nobody is playing. So the weekend lands on the
    /// person you have neglected once the founder has actually picked up
    /// the phone at least once; before that it is the anonymous night out
    /// it has always been.
    static func spendWeekend(_ state: inout GameState, _ content: ContentCatalog) {
        guard !state.life.friends.friends.isEmpty else { return }
        guard let neglected = state.life.friends.mostNeglected else { return }
        let day = state.day
        bump(neglected.id, by: tuning.weekendBond, contact: true, seen: true, state: &state)
        post(neglected.id, weekendLine(neglected), day: day, state: &state)
        for other in state.life.friends.friends
        where other.id != neglected.id && !other.hasMovedAway && !other.isOnPayroll {
            bump(other.id, by: tuning.weekendBystanderBond, contact: false, seen: false, state: &state)
        }
    }

    private static func weekendLine(_ friend: Friend) -> String {
        switch friend.archetype {
        case .uniFriend: "Good to see you out of that office. Same time in a fortnight?"
        case .exColleague: "You talked about work for one hour and forty minutes. I timed it. Still fun."
        case .neighbour: "That was lovely. You looked like a person again for a bit."
        }
    }

    // MARK: - Actions

    /// A phone call: free, once a week, and the cheapest way to keep
    /// somebody in your life.
    static func call(
        friendID: UUID,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard callBlocker(friendID: friendID, state: state, content: content) == nil else { return [] }
        materialise(&state, content)
        guard let friend = state.life.friends.friend(friendID) else { return [] }
        let day = state.day
        bump(friendID, by: tuning.callBond, contact: true, seen: false, state: &state)
        if let index = index(friendID, state) {
            state.life.friends.friends[index].lastCallDay = day
        }
        state.life.phone.post(
            "Called you. Good to hear your voice.",
            from: .friend(friendID), day: day, fromFounder: true
        )
        post(friendID, callLine(friend), day: day, state: &state)
        return []
    }

    private static func callLine(_ friend: Friend) -> String {
        switch friend.archetype {
        case .uniFriend: "Twenty minutes of you explaining your architecture. I understood four words. Loved it."
        case .exColleague: "Good call. You sound tired. Delegate something."
        case .neighbour: "Nice to hear you. Bins are out, don't worry about it."
        }
    }

    static func callBlocker(friendID: UUID, state: GameState, content: ContentCatalog) -> String? {
        guard let friend = state.friend(friendID, content: content) else {
            return "You've lost their number"
        }
        if friend.isOnPayroll { return "They work for you now — talk to them at the office" }
        if let last = friend.lastCallDay {
            let wait = tuning.callCooldownDays - (state.day - last)
            if wait > 0 { return "You spoke this week — try again in \(wait) day\(wait == 1 ? "" : "s")" }
        }
        return nil
    }

    /// An evening with somebody. The most expensive thing in the feature
    /// and the only one that moves the relationships meter.
    static func see(
        friendID: UUID,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard seeBlocker(friendID: friendID, state: state, balance: balance, content: content) == nil
        else { return [] }
        materialise(&state, content)
        guard let friend = state.life.friends.friend(friendID) else { return [] }
        let day = state.day
        state.spendEvening(balance)
        state.life.wallet -= tuning.seeCost
        state.life.meters.apply(
            energy: tuning.seeEnergy,
            mood: tuning.seeMood,
            relationships: tuning.seeRelationships
        )
        state.economy.lonelySinceDay = nil
        bump(friendID, by: tuning.seeBond, contact: true, seen: true, state: &state)
        post(friendID, seeLine(friend), day: day, state: &state)
        return []
    }

    private static func seeLine(_ friend: Friend) -> String {
        switch friend.archetype {
        case .uniFriend: "Home. Still laughing about the thing with the whiteboard. Do that again."
        case .exColleague: "Two drinks and a whole strategy. Bill me for the second one."
        case .neighbour: "Left the porch light on for you. Good evening, that."
        }
    }

    static func seeBlocker(
        friendID: UUID,
        state: GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> String? {
        guard let friend = state.friend(friendID, content: content) else {
            return "You've lost their number"
        }
        if friend.isOnPayroll { return "They work for you now — that's a team dinner, not an evening" }
        if friend.hasMovedAway { return "They live abroad now — call instead" }
        if state.life.isAway(day: state.day) { return "You're away" }
        if let blocker = state.eveningBlocker(balance) { return blocker }
        if state.life.wallet < tuning.seeCost {
            return "Need \((tuning.seeCost - state.life.wallet).friendMoney) more in your wallet"
        }
        return nil
    }

    // MARK: Offers

    /// Puts a friend on the payroll. Built the way the game hires anybody:
    /// a `Candidate` first, then the normal hire — and then the bond they
    /// already had is written onto the employee, so somebody who has known
    /// you for fifteen years does not arrive as a stranger.
    static func hire(
        friendID: UUID,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard hireBlocker(friendID: friendID, state: state, balance: balance, content: content) == nil
        else { return [] }
        materialise(&state, content)
        guard let friend = state.life.friends.friend(friendID) else { return [] }

        let skills = friend.derivedSkills
        let salary = Int((Double(balance.salaryBase)
            + balance.salaryPerSkillPoint * skills.total).rounded())
        state.candidatePool.append(Candidate(
            id: friend.id,
            name: friend.name,
            skills: skills,
            weeklySalary: salary,
            appearanceSeed: friend.appearanceSeed,
            role: friend.archetype == .uniFriend ? .backend : .ops
        ))
        let events = EmployeeSystem.hire(candidateID: friend.id, state: &state, balance: balance)
        guard !events.isEmpty else {
            // Refused at the door; take the candidate back out so the
            // hiring desk does not quietly gain a friend.
            state.candidatePool.removeAll { $0.id == friend.id }
            return []
        }
        if let index = state.employees.firstIndex(where: { $0.id == friend.id }) {
            state.employees[index].founderBond = friend.bond
        }
        if let index = index(friendID, state) {
            state.life.friends.friends[index].hiredDay = state.day
            state.life.friends.friends[index].bond = min(100, friend.bond + tuning.hireBond)
            state.life.friends.friends[index].lastContactDay = state.day
        }
        post(friendID, "First day Monday. I'm not calling you boss.", day: state.day, state: &state)
        return events
    }

    static func hireBlocker(
        friendID: UUID,
        state: GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> String? {
        guard let friend = state.friend(friendID, content: content) else {
            return "You've lost their number"
        }
        if friend.isOnPayroll { return "Already on the payroll" }
        if friend.archetype == .neighbour { return "They have a job they like and no interest in yours" }
        if friend.hasMovedAway { return "They live abroad now" }
        if friend.bond < tuning.hireBondGate {
            return "They'd have to trust you more (\(Int(friend.bond.rounded()))/\(Int(tuning.hireBondGate)))"
        }
        if state.headcount >= balance.office(state.company.officeTier).headcountCap {
            return "No desk free — upgrade the office"
        }
        return nil
    }

    /// Backs a friend's company out of the founder's own wallet, using the
    /// same `Holding` machinery a networking stake uses — so it drifts,
    /// exits and folds exactly like every other stake.
    static func invest(
        friendID: UUID,
        amount: Int,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard investBlocker(friendID: friendID, amount: amount, state: state, content: content) == nil
        else { return [] }
        materialise(&state, content)
        guard let friend = state.life.friends.friend(friendID),
              let company = friend.companyName
        else { return [] }

        let valuation = max(1, friend.companyValuation)
        let stake = min(tuning.maximumStakePercent, Double(amount) / Double(valuation) * 100)
        state.life.wallet -= amount
        state.networking.holdings.append(Holding(
            id: friend.id,
            companyName: company,
            stakePercent: stake,
            invested: amount,
            valuation: valuation,
            boughtDay: state.day
        ))
        bump(friendID, by: tuning.investBond, contact: true, seen: false, state: &state)
        post(friendID,
             "Money landed. You own \(String(format: "%.1f", stake))% of \(company) and I owe you a very good dinner.",
             day: state.day, state: &state)
        return []
    }

    static func investBlocker(
        friendID: UUID,
        amount: Int,
        state: GameState,
        content: ContentCatalog
    ) -> String? {
        guard let friend = state.friend(friendID, content: content) else {
            return "You've lost their number"
        }
        guard friend.companyName != nil else { return "They haven't started anything yet" }
        if state.networking.holdings.contains(where: { $0.id == friend.id }) {
            return "You already own a piece of it"
        }
        if friend.bond < tuning.investBondGate {
            return "They'd rather not take your money yet (\(Int(friend.bond.rounded()))/\(Int(tuning.investBondGate)))"
        }
        if amount < tuning.minimumInvestment {
            return "The smallest cheque worth writing is \(tuning.minimumInvestment.friendMoney)"
        }
        if state.life.wallet < amount {
            return "Need \((amount - state.life.wallet).friendMoney) more in your wallet"
        }
        return nil
    }

    /// A personal loan. No interest, no paperwork, and no company money —
    /// this is the founder's own wallet, borrowed from somebody who trusts
    /// them. It costs nothing until it goes unpaid past 26 weeks.
    static func borrow(
        friendID: UUID,
        amount: Int,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard borrowBlocker(friendID: friendID, amount: amount, state: state, content: content) == nil
        else { return [] }
        materialise(&state, content)
        guard let index = index(friendID, state) else { return [] }
        var friend = state.life.friends.friends[index]
        state.life.wallet += amount
        if var loan = friend.loan {
            loan.outstanding += amount
            loan.principal += amount
            loan.borrowedDay = state.day
            friend.loan = loan
        } else {
            friend.loan = FriendLoan(outstanding: amount, principal: amount, borrowedDay: state.day)
        }
        friend.lastContactDay = state.day
        state.life.friends.friends[index] = friend
        post(friendID, "Sent. Pay me back when the company can. I'm not counting the weeks — much.",
             day: state.day, state: &state)
        return []
    }

    static func borrowBlocker(
        friendID: UUID,
        amount: Int,
        state: GameState,
        content: ContentCatalog
    ) -> String? {
        guard let friend = state.friend(friendID, content: content) else {
            return "You've lost their number"
        }
        if friend.isOnPayroll { return "They're on your payroll — that's a salary conversation" }
        if friend.bond < tuning.borrowBondGate {
            return "You are not close enough to ask (\(Int(friend.bond.rounded()))/\(Int(tuning.borrowBondGate)))"
        }
        let ceiling = friend.loanCeiling(tuning)
        if amount <= 0 { return "Ask for something" }
        if amount > ceiling {
            return ceiling <= 0
                ? "They've lent you all they can"
                : "They can spare \(ceiling.friendMoney), not \(amount.friendMoney)"
        }
        return nil
    }

    /// Pays a friend back out of the wallet. Clearing it entirely is worth
    /// bond; a part payment just stops the bleed.
    static func repay(
        friendID: UUID,
        amount: Int,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard repayBlocker(friendID: friendID, amount: amount, state: state, content: content) == nil,
              let index = index(friendID, state),
              var loan = state.life.friends.friends[index].loan
        else { return [] }
        let paid = min(amount, loan.outstanding)
        state.life.wallet -= paid
        loan.outstanding -= paid
        let cleared = loan.outstanding <= 0
        state.life.friends.friends[index].loan = cleared ? nil : loan
        if cleared {
            bump(friendID, by: tuning.repaidBond, contact: true, seen: false, state: &state)
            post(friendID, "All square. Never doubted it. Next round's yours anyway.",
                 day: state.day, state: &state)
        }
        return []
    }

    static func repayBlocker(
        friendID: UUID,
        amount: Int,
        state: GameState,
        content: ContentCatalog
    ) -> String? {
        guard let friend = state.friend(friendID, content: content) else {
            return "You've lost their number"
        }
        guard let loan = friend.loan, loan.outstanding > 0 else { return "You don't owe them anything" }
        if amount <= 0 { return "Nothing to pay" }
        let due = min(amount, loan.outstanding)
        if state.life.wallet < due {
            return "Need \((due - state.life.wallet).friendMoney) more in your wallet"
        }
        return nil
    }

    // MARK: - Helpers

    private static func index(_ friendID: UUID, _ state: GameState) -> Int? {
        state.life.friends.friends.firstIndex { $0.id == friendID }
    }

    private static func bump(
        _ friendID: UUID,
        by delta: Double,
        contact: Bool,
        seen: Bool,
        state: inout GameState
    ) {
        guard let index = index(friendID, state) else { return }
        var friend = state.life.friends.friends[index]
        friend.bond = min(100, max(0, friend.bond + delta))
        if contact { friend.lastContactDay = state.day }
        if seen { friend.lastSeenDay = state.day }
        state.life.friends.friends[index] = friend
    }

    private static func replace(_ friend: Friend, in state: inout GameState) {
        guard let index = index(friend.id, state) else { return }
        state.life.friends.friends[index] = friend
    }

    private static func post(
        _ friendID: UUID,
        _ text: String,
        day: Int,
        state: inout GameState
    ) {
        state.life.phone.post(text, from: .friend(friendID), day: day)
    }
}

extension Int {
    /// `$1,200` for a blocker written in the engine, where the app's own
    /// money formatter is not available.
    var friendMoney: String {
        let digits = String(abs(self))
        var grouped = ""
        for (offset, character) in digits.reversed().enumerated() {
            if offset > 0, offset % 3 == 0 { grouped.append(",") }
            grouped.append(character)
        }
        return "\(self < 0 ? "−" : "")$\(String(grouped.reversed()))"
    }
}
