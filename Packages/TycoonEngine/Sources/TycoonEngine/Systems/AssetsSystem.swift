import Foundation
import TycoonContent

/// Iteration 11 — N3. The founder's own balance sheet and their own body.
///
/// **Nothing here runs until the player opens the Assets screen.** Both
/// entry points return on their first line while `state.assets` is
/// `.empty`, and `.empty` is what it stays until `.noticeAssetsOpened`
/// arrives from `AssetsScreen`. A pacing bot never opens a screen, so a
/// bot's run draws nothing from `socialRNG` here and writes the same save
/// it wrote before this file existed.
///
/// Two entry points, both fixed in the tick order:
///
/// - `applyLife` runs from `LifeSystem`'s N3 region, right after the
///   thresholds, so the vices and the ailments drift on the same meters
///   the same day the schedule does. **Draws nothing.**
/// - `run` runs last in `Reducer.systems`, and does the weekly work on
///   day % 7 == 0: the bills, then the things that go wrong. Its draws,
///   all on `socialRNG`, in this order and no other:
///   1. per owned thing in catalog-id order: the loss roll (one word,
///      only when `lossChance > 0`), then the fault roll (one word, only
///      when `faultChance > 0`);
///   2. the crypto step (two words — a gaussian — only while a wallet is
///      open);
///   3. the lottery draw (one word, only while a ticket is held).
///
/// The interventions and the ailment diagnoses draw nothing at all: both
/// are read off numbers the player moved.
enum AssetsSystem {
    /// The story flags this lane raises. Every `asset_` and `vice_` life
    /// event in `LifeEvents.json` is gated on one of them, which is what
    /// keeps thirty-four new beats out of the draw pool of a run that
    /// never opens the Assets screen: the eligible set is filtered before
    /// the weighted pick, so an ineligible beat does not shift a single
    /// `rng` word.
    static let engagedFlag = "assets_engaged"
    static let garageFlag = "assets_garage"
    static let propertyFlag = "assets_property"
    static let petFlag = "assets_pet"
    static let casinoFlag = "assets_casino"
    static let cryptoFlag = "assets_crypto"
    static let doctorFlag = "assets_doctor"
    static let interventionFlag = "vice_intervention"

    // MARK: - The tick

    /// The weekly pass: bills, breakdowns, thefts, floods, the vet, the
    /// wallet, the ticket, and the vices' own week.
    @Sendable
    static func run(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        guard state.assets.isEngaged else { return [] }
        guard state.day % GameState.daysPerWeek == 0 else { return [] }

        var events: [GameEvent] = []
        let config = balance.assets

        // 1. The bills. Everything the founder owns takes its cut, and a
        //    tenanted flat pays some of it back.
        let net = state.assetWeeklyCosts(balance: balance)
        if net != 0 { state.life.wallet -= net }

        // 2. What went wrong this week, in catalog-id order.
        events.append(contentsOf: rollMishaps(&state, config))

        // 3. The wallet that moves on its own.
        stepCrypto(&state, config)

        // 4. The ticket.
        if let ticket = state.assets.ticket, state.day > ticket.boughtDay {
            events.append(contentsOf: drawLottery(&state, config))
        }

        // 5. The vices' week: the decay first, then what the week added.
        events.append(contentsOf: runViceWeek(&state, balance))

        state.assets.stakedThisWeek = 0
        return events
    }

    /// The daily pass, from `LifeSystem`'s N3 region. The founder's things
    /// and the founder's habits, on the same meters, and then the doctor's
    /// arithmetic. Draws nothing.
    static func applyLife(_ state: inout GameState, _ balance: BalanceConfig) -> [GameEvent] {
        guard state.assets.isEngaged else { return [] }
        let config = balance.assets

        // The things you own, and what they are worth to be around.
        var mood = state.assetMoodDrift(balance: balance)
        var energy = 0.0
        var health = 0.0
        var relationships = state.assets.owned.reduce(0.0) { total, owned in
            guard let def = config.asset(owned.catalogID) else { return total }
            return total + def.prestige
        } * balance.instantLife.prestigeRelationshipFactor

        // The habits, scaled by how far in the founder is.
        for id in state.assets.vices.keys.sorted() {
            let dependency = state.assets.dependency(id)
            guard dependency > 0, let def = config.vice(id) else { continue }
            let scale = dependency / 100
            mood += def.moodDrift * scale
            health += def.healthDrift * scale
            energy += def.energyDrift * scale
            relationships += def.relationshipsDrift * scale
        }

        // What the founder is living with, until it is treated.
        for ailment in state.assets.ailments.sorted(by: { $0.id < $1.id }) {
            guard let def = config.ailment(ailment.id) else { continue }
            mood += def.mood
            health += def.health
            energy += def.energy
            relationships += def.relationships
        }

        state.life.meters.apply(
            energy: energy, health: health, mood: mood, relationships: relationships
        )

        // A finished course of treatment clears on its last day.
        var events: [GameEvent] = []
        for ailment in state.assets.ailments where (ailment.treatedUntilDay ?? .max) <= state.day {
            state.assets.ailments.removeAll { $0.id == ailment.id }
            events.append(.ailmentCleared(ailmentID: ailment.id, day: state.day))
        }

        // The counters the diagnoses read.
        state.assets.lowMoodDays = state.life.meters.mood < config.lowMoodLine
            ? state.assets.lowMoodDays + 1 : 0
        state.assets.lowHealthDays = state.life.meters.health < config.lowHealthLine
            ? state.assets.lowHealthDays + 1 : 0

        events.append(contentsOf: diagnose(&state, balance))
        events.append(contentsOf: lapseStaleQuits(&state, balance))
        return events
    }

    // MARK: - The week

    private static func rollMishaps(
        _ state: inout GameState,
        _ config: BalanceConfig.AssetsBalance
    ) -> [GameEvent] {
        var events: [GameEvent] = []
        for owned in state.assets.owned.sorted(by: { $0.catalogID < $1.catalogID }) {
            guard let def = config.asset(owned.catalogID) else { continue }

            // Gone off the drive. Only cars: a flat cannot be stolen, and
            // a pet that wanders off comes back by tea time.
            if def.assetKind == .car, def.lossChance > 0 {
                if state.socialRNG.nextUniform() < def.lossChance {
                    state.assets.owned.removeAll { $0.catalogID == owned.catalogID }
                    state.life.meters.apply(mood: -config.lossMoodPenalty)
                    // MARK: Iteration 11 — N3: the car leaves the driveway
                    // slot with it.
                    HomeDecor.remove(
                        slot: HomeDecor.drivewaySlotID, tier: state.life.home, decor: &state.life.decor
                    )
                    events.append(.assetStolen(assetID: owned.catalogID, day: state.day))
                    continue
                }
            }

            // Something has stopped working.
            guard def.faultChance > 0, !owned.needsRepair else { continue }
            guard state.socialRNG.nextUniform() < def.faultChance else { continue }
            state.assets.setNeedsRepair(owned.catalogID)
            switch def.assetKind {
            case .car:
                events.append(.assetBrokeDown(assetID: owned.catalogID, bill: def.repairCost, day: state.day))
            case .property:
                events.append(.assetFlooded(assetID: owned.catalogID, bill: def.repairCost, day: state.day))
            case .pet:
                // The vet does not wait to be paid, and the animal is
                // fine — which is the only reason the bill is bearable.
                state.life.wallet -= def.repairCost
                state.assets.setNeedsRepair(owned.catalogID, false)
                events.append(.petVetBill(
                    assetID: owned.catalogID, name: owned.petName, bill: def.repairCost, day: state.day
                ))
            }
        }
        return events
    }

    private static func stepCrypto(_ state: inout GameState, _ config: BalanceConfig.AssetsBalance) {
        guard var wallet = state.assets.crypto else { return }
        let step = config.crypto.weeklyDrift + state.socialRNG.nextGaussian(sigma: config.crypto.weeklySigma)
        wallet.price = min(config.crypto.maxPrice, max(config.crypto.minPrice, wallet.price * exp(step)))
        state.assets.crypto = wallet
    }

    private static func drawLottery(
        _ state: inout GameState,
        _ config: BalanceConfig.AssetsBalance
    ) -> [GameEvent] {
        state.assets.ticket = nil
        let lottery = config.lottery
        let roll = state.socialRNG.nextUniform()
        let prize: Int
        if roll < lottery.jackpotChance {
            prize = lottery.jackpot
        } else if roll < lottery.jackpotChance + lottery.midChance {
            prize = lottery.midPrize
        } else if roll < lottery.jackpotChance + lottery.midChance + lottery.smallChance {
            prize = lottery.smallPrize
        } else {
            prize = 0
        }
        state.life.wallet += prize
        return [.lotteryDrawn(prize: prize, day: state.day)]
    }

    /// The vices' week: everything decays, then crunch and any launch put
    /// it back, and anybody who crossed a line hears about it.
    private static func runViceWeek(
        _ state: inout GameState,
        _ balance: BalanceConfig
    ) -> [GameEvent] {
        let config = balance.assets
        let crunched = state.effectiveSchedule == .crunch
        state.assets.crunchWeeks = crunched ? state.assets.crunchWeeks + 1 : 0
        // A launch is a party, and a party is a late one. The week's
        // `.shipped` events are already in the log by the time this runs.
        let launches = state.eventLog.count {
            if case .shipped(_, let day) = $0 { state.day - day < GameState.daysPerWeek } else { false }
        }

        for def in config.vices {
            var value = state.assets.dependency(def.id) - def.weeklyDecay
            if crunched { value += def.perCrunchWeek }
            value += def.perLaunch * Double(launches)
            // MARK: K7 (partner and diary) — a date kept is a launch party skipped.
            value -= def.perLaunch * Double(DiaryRoadmap.partiesSkipped(state))
            // MARK: end K7
            // MARK: T6 (away) — a launch the founder was away for is a party nobody threw (never counted twice with a kept date).
            value -= def.perLaunch * Double(min(max(0, launches - DiaryRoadmap.partiesSkipped(state)), AwaySystem.partiesMissed(state)))
            // MARK: end T6
            // MARK: X4 (the launch party) — a party actually thrown, on
            // crunch, is a later one still: the napkin J1's vices door
            // arrives on has always come from this party, and now there is
            // one. Exactly 0 on every run nobody threw a party in, and off
            // crunch.
            if crunched {
                value += def.perLaunch * balance.party.viceCrunchFactor
                    * Double(LaunchPartyMath.thrownThisWeek(state))
            }
            // MARK: end X4
            state.assets.setDependency(def.id, value)
        }

        // Somebody who loves you says something. Once per vice per run,
        // and only when there is somebody to say it.
        var events: [GameEvent] = []
        for def in config.vices where state.assets.dependency(def.id) >= def.interventionAt {
            guard !state.assets.intervened.contains(def.id) else { continue }
            guard let who = interventionist(state) else { continue }
            state.assets.intervened.append(def.id)
            state.assets.intervened.sort()
            state.narrative.flags.insert(interventionFlag)
            state.life.phone.post(
                interventionLine(def, from: who), from: interventionThread(state), day: state.day
            )
            events.append(.viceIntervention(viceID: def.id, from: who, day: state.day))
        }
        return events
    }

    /// Who sits the founder down: the partner if there is one, otherwise
    /// the friend who has been around longest. Nobody, and nobody says
    /// anything — which is its own kind of dark.
    private static func interventionist(_ state: GameState) -> String? {
        if let partner = state.life.family.partnerName, state.life.family.stage != .single {
            return partner
        }
        return state.life.friends.friends.first?.firstName
    }

    private static func interventionThread(_ state: GameState) -> PhoneCounterpart {
        if state.life.family.stage != .single { return .partner }
        if let friend = state.life.friends.friends.first { return .friend(friend.id) }
        return .partner
    }

    private static func interventionLine(_ def: BalanceConfig.AssetsBalance.AssetViceDef, from who: String) -> String {
        switch def.id {
        case "drink": "\(who) counted the bottles in the recycling. They did not make it a joke."
        case "caffeine": "\(who) has started hiding the good beans. You have found them twice."
        case "gambling": "\(who) asked what the card statement was. You had the answer ready, which is worse."
        case "phone": "\(who) put your phone in the drawer at dinner and did not say anything about it."
        default: "\(who) wants to talk about it. Not tonight — tomorrow, properly."
        }
    }

    // MARK: - The doctor

    /// What the founder has picked up, read off the numbers rather than
    /// rolled. Everything here is the consequence of a run of weeks the
    /// player chose.
    private static func diagnose(_ state: inout GameState, _ balance: BalanceConfig) -> [GameEvent] {
        let config = balance.assets
        var events: [GameEvent] = []
        for def in config.ailments where !state.assets.hasAilment(def.id) {
            guard caught(def, state, balance) else { continue }
            state.assets.ailments.append(AssetAilment(id: def.id, sinceDay: state.day))
            state.assets.ailments.sort { $0.id < $1.id }
            state.narrative.flags.insert(doctorFlag)
            events.append(.ailmentDiagnosed(ailmentID: def.id, day: state.day))
        }
        return events
    }

    private static func caught(
        _ def: BalanceConfig.AssetsBalance.AssetAilmentDef,
        _ state: GameState,
        _ balance: BalanceConfig
    ) -> Bool {
        if def.crunchWeeks > 0, state.assets.crunchWeeks >= def.crunchWeeks { return true }
        if def.lowMoodDays > 0, state.assets.lowMoodDays >= def.lowMoodDays { return true }
        if def.lowHealthDays > 0, state.assets.lowHealthDays >= def.lowHealthDays { return true }
        if let vice = def.viceID, def.viceDependency > 0,
           state.assets.dependency(vice) >= def.viceDependency { return true }
        if def.burnouts > 0 {
            let window = balance.economy.burnoutWindowDays
            let recent = state.economy.burnoutDays.count { state.day - $0 < window }
            if recent >= def.burnouts { return true }
        }
        return false
    }

    /// A run of evenings left alone long enough stops being a run.
    private static func lapseStaleQuits(
        _ state: inout GameState,
        _ balance: BalanceConfig
    ) -> [GameEvent] {
        let lapse = balance.assets.quitting.lapseDays
        guard lapse > 0 else { return [] }
        var events: [GameEvent] = []
        for quit in state.assets.quits.sorted(by: { $0.viceID < $1.viceID }) {
            let last = max(quit.lastEveningDay, quit.startedDay)
            guard state.day - last >= lapse else { continue }
            state.assets.quits.removeAll { $0.viceID == quit.viceID }
            events.append(.viceRelapsed(viceID: quit.viceID, day: state.day))
        }
        return events
    }

    // MARK: - Actions

    /// The one flag this lane has: the player has been to the Assets
    /// screen, so everything above may start. Nothing else sets it, which
    /// is what keeps the pacing bots and the fixtures where they are.
    static func noticeOpened(_ state: inout GameState) -> [GameEvent] {
        guard !state.assets.opened else { return [] }
        state.assets.opened = true
        state.narrative.flags.insert(engagedFlag)
        return []
    }

    // MARK: J1 (doors)

    /// The vices door, answered yes: the room is engaged exactly as the
    /// screen would engage it, and the habit a launch party feeds most
    /// starts at what one launch party adds. Nothing draws.
    static func doorEngage(state: inout GameState, balance: BalanceConfig) -> [GameEvent] {
        let events = noticeOpened(&state)
        guard let def = balance.assets.vices.max(by: { $0.perLaunch < $1.perLaunch }),
              def.perLaunch > 0
        else { return events }
        let seeded = max(state.assets.dependency(def.id), def.perLaunch)
        state.assets.setDependency(def.id, seeded)
        return events
    }

    // MARK: end J1

    /// Buys a car, a property or a pet from the catalog with the
    /// founder's own money. A pet is given a name on `socialRNG`; nothing
    /// else here draws.
    static func buy(
        _ catalogID: String,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard buyBlocker(catalogID, state: state, balance: balance) == nil,
              let def = balance.assets.asset(catalogID)
        else { return [] }

        state.life.wallet -= def.price
        var owned = AssetOwned(catalogID: def.id, kind: def.assetKind, boughtDay: state.day)
        switch def.assetKind {
        case .pet:
            let names = balance.assets.petNames
            if !names.isEmpty {
                owned.petName = names[state.socialRNG.nextInt(in: 0...(names.count - 1))]
            }
        case .property:
            // A second home is let out unless it is the cabin, which
            // exists so that somebody can go there.
            owned.letOut = def.weeklyRent > 0
        case .car:
            break
        }
        state.assets.owned.append(owned)
        state.assets.owned.sort { $0.catalogID < $1.catalogID }
        state.narrative.flags.insert(engagedFlag)
        switch def.assetKind {
        case .car: state.narrative.flags.insert(garageFlag)
        case .property: state.narrative.flags.insert(propertyFlag)
        case .pet: state.narrative.flags.insert(petFlag)
        }

        // MARK: Iteration 11 — N3: a car goes on the drive and a pet gets
        // its basket, the same way a bought possession puts itself away.
        if let slot = HomeDecor.assetSlotID(for: def.assetKind) {
            HomeDecor.place(
                itemID: HomeDecor.assetDecorID(def.id), slot: slot,
                tier: state.life.home, decor: &state.life.decor
            )
        }
        return [.assetBought(assetID: def.id, price: def.price, day: state.day)]
    }

    /// Why the founder cannot have it, in their own words.
    static func buyBlocker(
        _ catalogID: String,
        state: GameState,
        balance: BalanceConfig
    ) -> String? {
        guard let def = balance.assets.asset(catalogID) else { return "Not for sale." }
        if state.assets.owns(catalogID) { return "You already have one." }
        if state.life.wallet < def.price {
            return "You are \((def.price - state.life.wallet).money) short."
        }
        if state.life.isAway(day: state.day) { return "Not from where you are." }
        return nil
    }

    /// Sells it back at the catalog's resale fraction, docked while it is
    /// off the road.
    static func sell(
        _ catalogID: String,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard let owned = state.assets.asset(catalogID),
              let def = balance.assets.asset(catalogID)
        else { return [] }
        let price = resalePrice(owned, def, balance)
        state.life.wallet += price
        state.assets.owned.removeAll { $0.catalogID == catalogID }
        // MARK: Iteration 11 — N3: and off the drive.
        if let slot = HomeDecor.assetSlotID(for: def.assetKind) {
            HomeDecor.remove(slot: slot, tier: state.life.home, decor: &state.life.decor)
        }
        // Selling the dog is not a transaction the founder feels good
        // about, whatever the number says.
        if def.assetKind == .pet { state.life.meters.apply(mood: -balance.assets.lossMoodPenalty) }
        return [.assetSold(assetID: catalogID, price: price, day: state.day)]
    }

    static func resalePrice(
        _ owned: AssetOwned,
        _ def: BalanceConfig.AssetsBalance.AssetDef,
        _ balance: BalanceConfig
    ) -> Int {
        let base = Double(def.price) * def.resaleFraction
        return Int((owned.needsRepair ? base * balance.assets.brokenResaleFactor : base).rounded())
    }

    /// Pays the bill and puts the thing back on the road.
    static func repair(
        _ catalogID: String,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard let owned = state.assets.asset(catalogID), owned.needsRepair,
              let def = balance.assets.asset(catalogID),
              state.life.wallet >= def.repairCost
        else { return [] }
        state.life.wallet -= def.repairCost
        state.assets.setNeedsRepair(catalogID, false)
        return [.assetRepaired(assetID: catalogID, cost: def.repairCost, day: state.day)]
    }

    static func repairBlocker(
        _ catalogID: String,
        state: GameState,
        balance: BalanceConfig
    ) -> String? {
        guard let def = balance.assets.asset(catalogID) else { return "Not yours." }
        guard state.assets.asset(catalogID)?.needsRepair == true else { return "Nothing wrong with it." }
        if state.life.wallet < def.repairCost {
            return "The bill is \(def.repairCost.money). You are \((def.repairCost - state.life.wallet).money) short."
        }
        return nil
    }

    // MARK: The doctor's office

    /// Starts a course of treatment: the bill now, the clearance in
    /// `treatmentDays`. Costs an evening; draws nothing.
    static func treat(
        _ ailmentID: String,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard treatBlocker(ailmentID, state: state, balance: balance) == nil,
              let def = balance.assets.ailment(ailmentID),
              let index = state.assets.ailments.firstIndex(where: { $0.id == ailmentID })
        else { return [] }
        state.life.wallet -= def.treatmentCost
        state.assets.ailments[index].treatedUntilDay = state.day + def.treatmentDays
        state.spendEvening(balance)
        return [.ailmentTreated(ailmentID: ailmentID, cost: def.treatmentCost, day: state.day)]
    }

    static func treatBlocker(
        _ ailmentID: String,
        state: GameState,
        balance: BalanceConfig
    ) -> String? {
        guard let def = balance.assets.ailment(ailmentID),
              let ailment = state.assets.ailments.first(where: { $0.id == ailmentID })
        else { return "You do not have it." }
        if let until = ailment.treatedUntilDay {
            return "Being treated — \(max(0, until - state.day)) day\(until - state.day == 1 ? "" : "s") to go."
        }
        if state.life.wallet < def.treatmentCost {
            return "You are \((def.treatmentCost - state.life.wallet).money) short of the course."
        }
        if let blocker = state.eveningBlocker(balance) { return blocker }
        return nil
    }

    /// An hour on the couch: every dependency down a notch, the mood up.
    static func therapy(state: inout GameState, balance: BalanceConfig) -> [GameEvent] {
        guard therapyBlocker(state: state, balance: balance) == nil else { return [] }
        let def = balance.assets.therapy
        state.life.wallet -= def.cost
        for id in balance.assets.vices.map(\.id) {
            guard state.assets.dependency(id) > 0 else { continue }
            state.assets.setDependency(id, state.assets.dependency(id) - def.viceRelief)
        }
        state.life.meters.apply(energy: def.energy, mood: def.mood)
        state.assets.lastTherapyDay = state.day
        state.spendEvening(balance)
        return [.therapyAttended(day: state.day)]
    }

    static func therapyBlocker(state: GameState, balance: BalanceConfig) -> String? {
        let def = balance.assets.therapy
        if state.life.wallet < def.cost {
            return "The hour is \(def.cost.money). You are \((def.cost - state.life.wallet).money) short."
        }
        if let last = state.assets.lastTherapyDay, state.day - last < def.cooldownDays {
            return "Your next hour is in \(def.cooldownDays - (state.day - last)) days."
        }
        if state.life.isAway(day: state.day) { return "Not from where you are." }
        if let blocker = state.eveningBlocker(balance) { return blocker }
        return nil
    }

    // MARK: The vices

    /// Starts a run of evenings off it, or spends the next one. One
    /// `socialRNG` word per evening: the relapse roll.
    static func quit(
        _ viceID: String,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard quitBlocker(viceID, state: state, balance: balance) == nil,
              balance.assets.vice(viceID) != nil
        else { return [] }
        let rules = balance.assets.quitting
        state.spendEvening(balance)

        guard let index = state.assets.quits.firstIndex(where: { $0.viceID == viceID }) else {
            state.assets.quits.append(AssetQuit(viceID: viceID, startedDay: state.day, lastEveningDay: state.day))
            state.assets.quits.sort { $0.viceID < $1.viceID }
            state.assets.setDependency(viceID, state.assets.dependency(viceID) - rules.perEvening)
            state.life.meters.apply(mood: -rules.moodCost)
            return [.viceQuitProgressed(viceID: viceID, evenings: 1, day: state.day)]
        }

        if state.socialRNG.nextUniform() < rules.relapseChance {
            state.assets.quits.remove(at: index)
            state.assets.setDependency(viceID, state.assets.dependency(viceID) + rules.relapseGain)
            state.life.meters.apply(mood: -rules.moodCost)
            return [.viceRelapsed(viceID: viceID, day: state.day)]
        }

        state.assets.quits[index].eveningsDone += 1
        state.assets.quits[index].lastEveningDay = state.day
        state.assets.setDependency(viceID, state.assets.dependency(viceID) - rules.perEvening)
        let done = state.assets.quits[index].eveningsDone + 1
        guard done >= rules.evenings else {
            state.life.meters.apply(mood: -rules.moodCost)
            return [.viceQuitProgressed(viceID: viceID, evenings: done, day: state.day)]
        }
        state.assets.quits.remove(at: index)
        state.assets.setDependency(viceID, 0)
        state.assets.intervened.removeAll { $0 == viceID }
        state.life.meters.apply(mood: rules.successMood)
        return [.viceQuit(viceID: viceID, day: state.day)]
    }

    static func quitBlocker(
        _ viceID: String,
        state: GameState,
        balance: BalanceConfig
    ) -> String? {
        guard balance.assets.vice(viceID) != nil else { return "Not a habit you have." }
        guard state.assets.dependency(viceID) > 0 else { return "Nothing to quit." }
        if let quit = state.assets.quit(viceID), quit.lastEveningDay == state.day {
            return "You have done tonight."
        }
        if state.life.isAway(day: state.day) { return "Not from where you are." }
        if let blocker = state.eveningBlocker(balance) { return blocker }
        return nil
    }

    /// Gives up on giving up. Costs nothing but the streak.
    static func abandonQuit(_ viceID: String, state: inout GameState) -> [GameEvent] {
        guard state.assets.quits.contains(where: { $0.viceID == viceID }) else { return [] }
        state.assets.quits.removeAll { $0.viceID == viceID }
        return [.viceRelapsed(viceID: viceID, day: state.day)]
    }

    // MARK: The games

    /// One hand, one `socialRNG` word. The stake leaves the wallet either
    /// way; a win pays it back at the game's multiple.
    static func gamble(
        _ gameID: String,
        stake: Int,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard gambleBlocker(gameID, stake: stake, state: state, balance: balance) == nil,
              let def = balance.assets.game(gameID)
        else { return [] }

        state.life.wallet -= stake
        state.assets.stakedThisWeek += stake
        let won = state.socialRNG.nextUniform() < def.winChance
        let back = won ? Int((Double(stake) * def.payout).rounded()) : 0
        state.life.wallet += back

        state.assets.setDependency(
            "gambling",
            state.assets.dependency("gambling") + def.viceGain
                + (balance.assets.vice("gambling")?.perGamble ?? 0)
        )
        for def in balance.assets.vices where def.perGamble > 0 && def.id != "gambling" {
            state.assets.setDependency(def.id, state.assets.dependency(def.id) + def.perGamble)
        }
        state.narrative.flags.insert(casinoFlag)
        return [.casinoHandPlayed(gameID: gameID, stake: stake, returned: back, day: state.day)]
    }

    static func gambleBlocker(
        _ gameID: String,
        stake: Int,
        state: GameState,
        balance: BalanceConfig
    ) -> String? {
        guard let def = balance.assets.game(gameID) else { return "That table is closed." }
        if stake < def.minStake { return "The table's minimum is \(def.minStake.money)." }
        if stake > def.maxStake { return "The table's maximum is \(def.maxStake.money)." }
        if state.life.wallet < stake { return "You do not have it on you." }
        if state.assets.stakedThisWeek + stake > balance.assets.weeklyStakeCap {
            return "The house has cut you off for the week."
        }
        if state.life.isAway(day: state.day) { return "Not from where you are." }
        return nil
    }

    /// One ticket a week. Drawn at the weekend.
    static func buyTicket(state: inout GameState, balance: BalanceConfig) -> [GameEvent] {
        guard ticketBlocker(state: state, balance: balance) == nil else { return [] }
        let lottery = balance.assets.lottery
        state.life.wallet -= lottery.ticketCost
        state.assets.ticket = AssetLotteryTicket(boughtDay: state.day)
        state.assets.setDependency(
            "gambling", state.assets.dependency("gambling") + lottery.viceGain
        )
        state.narrative.flags.insert(casinoFlag)
        return [.lotteryTicketBought(day: state.day)]
    }

    static func ticketBlocker(state: GameState, balance: BalanceConfig) -> String? {
        if state.assets.ticket != nil { return "This week's is in your coat." }
        if state.life.wallet < balance.assets.lottery.ticketCost { return "You do not have it on you." }
        return nil
    }

    /// Buys (`dollars > 0`) or sells (`dollars < 0`) at today's price,
    /// less the spread both ways. Opens the wallet on the first buy.
    /// Draws nothing — the price only moves on the weekly step.
    static func trade(
        dollars: Int,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard dollars != 0, tradeBlocker(dollars: dollars, state: state, balance: balance) == nil
        else { return [] }
        let config = balance.assets.crypto
        var wallet = state.assets.crypto
            ?? AssetCryptoWallet(price: config.startingPrice, openedDay: state.day)

        if dollars > 0 {
            let units = Double(dollars) * (1 - config.spread) / wallet.price
            wallet.units += units
            wallet.invested += dollars
            state.life.wallet -= dollars
        } else {
            let wanted = Double(-dollars)
            let units = min(wallet.units, wanted / wallet.price)
            let back = Int((units * wallet.price * (1 - config.spread)).rounded())
            wallet.units -= units
            wallet.invested -= back
            state.life.wallet += back
        }
        // Rounded to nothing: close the position rather than keep a dust
        // balance nobody can sell.
        if wallet.units < 0.000001 { wallet.units = 0 }
        state.assets.crypto = wallet
        state.narrative.flags.insert(cryptoFlag)
        return [.cryptoTraded(dollars: dollars, price: wallet.price, day: state.day)]
    }

    static func tradeBlocker(
        dollars: Int,
        state: GameState,
        balance: BalanceConfig
    ) -> String? {
        if dollars > 0, state.life.wallet < dollars { return "You do not have it." }
        if dollars < 0 {
            guard let wallet = state.assets.crypto, wallet.units > 0 else { return "Nothing to sell." }
        }
        return nil
    }
}

// MARK: - Small mutations

extension AssetsState {
    /// Sets a dependency, clamped to 0…100, and drops it from the save
    /// entirely at zero so a founder who quit is a founder with no record
    /// of it in the JSON.
    mutating func setDependency(_ id: String, _ value: Double) {
        let clamped = min(100, max(0, value))
        if clamped <= 0 {
            vices.removeValue(forKey: id)
        } else {
            vices[id] = clamped
        }
    }

    mutating func setNeedsRepair(_ catalogID: String, _ value: Bool = true) {
        guard let index = owned.firstIndex(where: { $0.catalogID == catalogID }) else { return }
        owned[index].needsRepair = value
    }
}

/// The app's `Int.money` (`Theme.swift`), repeated here because the
/// refusal lines this file writes are the player's own words and have to
/// read like money. `12400` → `"$12,400"`.
private extension Int {
    var money: String {
        let sign = self < 0 ? "-" : ""
        let digits = String(magnitude)
        var grouped = ""
        for (offset, character) in digits.reversed().enumerated() {
            if offset != 0, offset.isMultiple(of: 3) { grouped.append(",") }
            grouped.append(character)
        }
        return sign + "$" + String(grouped.reversed())
    }
}
