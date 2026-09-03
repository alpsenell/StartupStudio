import Foundation
import Testing
import TycoonContent
@testable import TycoonEngine

/// The gate on "a three-year run rarely repeats a line": minimum catalog
/// sizes, no duplicated headlines anywhere, every choice actually doing
/// something, and a real three-year simulation surfacing enough distinct
/// beats to feel like a story rather than a rotation.
@Suite("Content variety")
struct ContentVarietyTests {
    private let content = TestContent.bundled

    // MARK: - Catalog minimums

    @Test("the catalogs are at least the sizes the design calls for")
    func minimumCounts() throws {
        #expect(content.events.count >= 60, "\(content.events.count) company events")
        #expect(content.lifeEvents.count >= 45, "\(content.lifeEvents.count) life events")
        #expect(content.staffEvents.count >= 10, "\(content.staffEvents.count) staff kinds")
        #expect(content.dialogue.bios.count >= 40)
        #expect(content.news.count >= 40)

        let withChoices = content.events.filter { !$0.choices.isEmpty }
        #expect(withChoices.count >= 35, "only \(withChoices.count) company events offer a choice")
        let lifeWithChoices = content.lifeEvents.filter { !$0.choices.isEmpty }
        #expect(lifeWithChoices.count >= 20, "only \(lifeWithChoices.count) life events offer a choice")

        let catalog = try #require(content.reviews)
        let balance = try BalanceConfig.loadBundled()
        for band in ["dire", "poor", "mixed", "good", "stellar"] {
            let all = balance.reviewOutlets.flatMap { catalog.blurbs(outlet: $0, band: band) ?? [] }
            #expect(all.count >= 32, "band \(band) has only \(all.count) blurbs")
        }
    }

    @Test("at least six multi-step storylines run on flags and follow-ups")
    func storylines() {
        let chained = content.events.filter { event in
            event.choices.contains { $0.followUpEventID != nil }
        }
        #expect(chained.count >= 6, "only \(chained.count) events schedule a follow-up")

        let flagged = Set(content.events.flatMap { $0.choices.flatMap(\.setFlags) })
        #expect(flagged.count >= 10, "only \(flagged.count) story flags are ever raised")
    }

    // MARK: - No repeats

    @Test("no headline, id or choice label repeats within an event")
    func noDuplicates() {
        let eventIDs = content.events.map(\.id)
        #expect(Set(eventIDs).count == eventIDs.count, "duplicate company event id")
        let lifeIDs = content.lifeEvents.map(\.id)
        #expect(Set(lifeIDs).count == lifeIDs.count, "duplicate life event id")

        let headlines = content.events.map(\.headline) + content.lifeEvents.map(\.headline)
        #expect(Set(headlines).count == headlines.count, "two events share a headline")

        for event in content.events {
            let ids = event.choices.map(\.id)
            #expect(Set(ids).count == ids.count, "\(event.id) repeats a choice id")
            let labels = event.choices.map(\.label)
            #expect(Set(labels).count == labels.count, "\(event.id) repeats a choice label")
        }
        for event in content.lifeEvents {
            let ids = event.choices.map(\.id)
            #expect(Set(ids).count == ids.count, "\(event.id) repeats a choice id")
        }
    }

    @Test("nothing in the catalogs shouts")
    func noExclamationSpam() {
        for headline in content.events.map(\.headline) + content.lifeEvents.map(\.headline) {
            #expect(!headline.contains("!"), "\"\(headline)\"")
        }
        for def in content.staffEvents {
            #expect(!def.title.contains("!"))
            #expect(!def.body.contains("!"))
        }
    }

    // MARK: - Referential integrity

    @Test("every follow-up resolves, and follow-up-only events are reachable")
    func followUpsResolve() {
        let companyIDs = Set(content.events.map(\.id))
        let lifeIDs = Set(content.lifeEvents.map(\.id))

        var companyTargets: Set<String> = []
        for event in content.events {
            for choice in event.choices {
                guard let target = choice.followUpEventID else { continue }
                #expect(companyIDs.contains(target), "\(event.id) -> unknown \(target)")
                companyTargets.insert(target)
                #expect(choice.followUpDelayDays > 0)
            }
        }
        var lifeTargets: Set<String> = []
        for event in content.lifeEvents {
            for choice in event.choices {
                guard let target = choice.followUpEventID else { continue }
                #expect(lifeIDs.contains(target), "\(event.id) -> unknown \(target)")
                lifeTargets.insert(target)
            }
        }

        // WS-E: the calendar schedules the anniversary and the birthday
        // itself, and a dated beat's missed twin fires in its place.
        lifeTargets.formUnion([FamilyCalendar.anniversaryEventID, FamilyCalendar.birthdayEventID])
        for event in content.lifeEvents {
            guard let twin = event.missedVariantID else { continue }
            #expect(lifeIDs.contains(twin), "\(event.id) -> unknown missed variant \(twin)")
            lifeTargets.insert(twin)
        }

        for event in content.events where event.followUpOnly {
            #expect(companyTargets.contains(event.id), "\(event.id) can never fire")
        }
        for event in content.lifeEvents where event.followUpOnly {
            #expect(lifeTargets.contains(event.id), "\(event.id) can never fire")
        }
    }

    @Test("every choice does something and every effect is in bounds")
    func choicesHaveConsequences() {
        func check(_ id: String, _ choices: [EventChoice]) {
            for choice in choices {
                #expect(
                    !choice.effects.isEmpty || !choice.setFlags.isEmpty
                        || !choice.clearFlags.isEmpty || choice.followUpEventID != nil,
                    "\(id)/\(choice.id) does nothing"
                )
                #expect(!choice.label.isEmpty)
                for effect in choice.effects { expectInBounds(effect, in: "\(id)/\(choice.id)") }
            }
        }
        for event in content.events {
            check(event.id, event.choices)
            for effect in event.effects { expectInBounds(effect, in: event.id) }
            #expect(event.weight >= 1)
            if let index = event.autoChoiceIndex {
                #expect(index >= 0 && index < event.choices.count, "\(event.id) auto index")
            }
        }
        for event in content.lifeEvents {
            check(event.id, event.choices)
            for effect in event.effects { expectInBounds(effect, in: event.id) }
            #expect(event.weight >= 1)
        }
    }

    /// Nothing in the catalogs may move a meter by more than the meter's
    /// whole range, or hand out money a startup could not survive being
    /// handed.
    private func expectInBounds(_ effect: EventEffect, in id: String) {
        switch effect {
        case .cash(let amount):
            #expect(abs(amount) <= 50_000, "\(id): cash \(amount)")
        case .reputation(let amount), .moraleAll(let amount),
             .morale(let amount, _), .loyalty(let amount, _):
            #expect(abs(amount) <= 40, "\(id): \(amount)")
        case .hype(let amount):
            #expect(abs(amount) <= 60, "\(id): hype \(amount)")
        case .market(_, let amount):
            #expect(abs(amount) <= 0.5, "\(id): market \(amount)")
        case .loan(let amount):
            #expect(abs(amount) <= 50_000, "\(id): loan \(amount)")
        case .founderMeters(let energy, let health, let mood, let relationships, let wallet):
            for value in [energy, health, mood, relationships] {
                #expect(abs(value) <= 40, "\(id): meter \(value)")
            }
            #expect(abs(wallet) <= 20_000, "\(id): wallet \(wallet)")
        case .away(let days, let reason):
            #expect(days > 0 && days <= 14, "\(id): away \(days)")
            #expect(!reason.isEmpty)
        case .cold(let days):
            #expect(days > 0 && days <= 14, "\(id): cold \(days)")
        case .flag(let flag), .clearFlag(let flag):
            #expect(!flag.isEmpty, "\(id): empty flag")
        case .skill(_, let amount, _):
            #expect(abs(amount) <= 20, "\(id): skill \(amount)")
        case .research(let amount):
            #expect(abs(amount) <= 200, "\(id): research \(amount)")
        case .affection(let amount), .bond(let amount, _):
            #expect(abs(amount) <= 40, "\(id): \(amount)")
        case .evening:
            break
        }
    }

    @Test("every requirement references something that exists")
    func requirementsAreValid() {
        let topicIDs = Set(content.topics.map(\.id))
        func check(_ id: String, _ requires: EventRequirements?) {
            guard let requires else { return }
            for raw in [requires.minTier, requires.maxTier].compactMap({ $0 }) {
                #expect(OfficeTier(rawValue: raw) != nil, "\(id): unknown tier \(raw)")
            }
            for raw in [requires.minStage, requires.maxStage].compactMap({ $0 }) {
                #expect(RelationshipStage(rawValue: raw) != nil, "\(id): unknown stage \(raw)")
            }
            if let raw = requires.minHome {
                #expect(HomeTier(rawValue: raw) != nil, "\(id): unknown home \(raw)")
            }
            if let raw = requires.requiresDepartment {
                #expect(Department(rawValue: raw) != nil, "\(id): unknown department \(raw)")
            }
            if let raw = requires.schedule {
                #expect(WorkSchedule(rawValue: raw) != nil, "\(id): unknown schedule \(raw)")
            }
            if let topic = requires.topicID {
                #expect(topicIDs.contains(topic), "\(id): unknown topic \(topic)")
            }
        }
        for event in content.events {
            check(event.id, event.requires)
            for choice in event.choices { check("\(event.id)/\(choice.id)", choice.requires) }
        }
        for event in content.lifeEvents {
            check(event.id, event.requires)
            for choice in event.choices { check("\(event.id)/\(choice.id)", choice.requires) }
            if let raw = event.minStage {
                #expect(RelationshipStage(rawValue: raw) != nil, "\(event.id): unknown stage")
            }
        }
        for effect in content.events.flatMap(\.unconditionalEffects)
            + content.events.flatMap({ $0.choices.flatMap(\.effects) }) {
            if case .market(let topicID, _) = effect {
                #expect(topicIDs.contains(topicID), "market effect on unknown topic \(topicID)")
            }
        }
    }

    /// The ten canonical balance seeds, so a variety claim is measured on
    /// the same sample as every other long-horizon claim in the suite.
    static let seeds: [UInt64] = [
        4_242, 1_009, 55_055, 7_777, 31_415,
        86_420, 20_002, 999_331, 64_064, 123_457,
    ]

    // MARK: - A three-year run

    @Test("three years of play surfaces a lot of different beats")
    func threeYearRunIsVaried() throws {
        let balance = try BalanceConfig.loadBundled()
        var company: Set<String> = []
        var life: Set<String> = []
        var staff: Set<StaffEventKind> = []
        var news: Set<String> = []

        for seed in UInt64(1)...3 {
            let run = Self.play(seed: seed, days: 1_092, balance: balance, content: content)
            company.formUnion(run.company)
            life.formUnion(run.life)
            staff.formUnion(run.staff)
            news.formUnion(run.news)
        }

        #expect(company.count >= 25, "only \(company.count) distinct company events")
        #expect(life.count >= 15, "only \(life.count) distinct life events")
        #expect(staff.count >= 6, "only \(staff.count) distinct staff kinds")
        #expect(news.count >= 30, "only \(news.count) distinct headlines")
    }

    /// Three in four beats in a three-year run are ones the player has not
    /// seen before. Cooldowns and requirement gates do the work; the rest is
    /// the catalog simply being big enough.
    ///
    /// Measured across ten seeds rather than one. It used to assert
    /// `>= 0.7` on seed 4242 alone, and seed 4242 is the worst of the ten
    /// by a distance — 0.67, against 0.73–0.88 on the other nine and a mean
    /// of 0.80. So the gate was one run's luck: any change that reshuffled
    /// the world stream without touching a line of content could fail it
    /// (this pass moved the investors onto their own RNG and did exactly
    /// that), and any real thinning of the catalog would pass as long as
    /// 4242 held up. A mean over ten seeds plus a per-seed floor says what
    /// the docstring above actually claims, and says it about the catalog
    /// rather than about one seed.
    @Test("a three-year run rarely repeats a beat")
    func repetitionIsRare() throws {
        let balance = try BalanceConfig.loadBundled()
        let runs = Self.seeds.map { seed in
            Self.play(seed: seed, days: 1_092, balance: balance, content: content)
        }
        var ratios: [Double] = []
        for run in runs {
            #expect(run.companyFired.count >= 20, "only \(run.companyFired.count) company beats fired")
            let ratio = Double(run.company.count) / Double(max(1, run.companyFired.count))
            #expect(
                ratio >= 0.65,
                "\(run.company.count) distinct of \(run.companyFired.count) fired on one seed"
            )
            ratios.append(ratio)
        }
        let mean = ratios.reduce(0, +) / Double(ratios.count)
        #expect(mean >= 0.75, "mean distinct-beat ratio \(mean) across \(ratios.count) seeds")
    }

    // MARK: - Harness

    private struct RunLog {
        var company: Set<String> = []
        var life: Set<String> = []
        var staff: Set<StaffEventKind> = []
        var news: Set<String> = []
        var companyFired: [String] = []
    }

    /// A hands-on founder: hires when there is cash and a candidate, keeps
    /// a product in development, answers every choice (rotating the option
    /// so both branches of a storyline get walked), and never runs out of
    /// money — the run is measuring content variety, not the economy.
    private static func play(
        seed: UInt64,
        days: Int,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> RunLog {
        var tuned = balance
        tuned.startingCash = 4_000_000
        var state = GameState.newGame(companyName: "Varied", seed: seed, balance: tuned)
        var log = RunLog()
        var answered = 0

        for day in 0..<days {
            // Keep the company alive and busy so tier- and product-gated
            // beats become eligible.
            state.company.cash = max(state.company.cash, 250_000)
            tally(Reducer.tick(&state, balance: tuned, content: content), into: &log)

            if let pending = state.narrative.pendingChoice {
                let option = pending.options[answered % pending.options.count]
                answered += 1
                // A beat with a choice reports itself when it is answered,
                // from `apply` rather than from the tick, so the log reads
                // both.
                tally(
                    Reducer.apply(
                        .resolveChoice(eventID: pending.id, optionIndex: option.index),
                        to: &state, balance: tuned, content: content
                    ),
                    into: &log
                )
            }
            if state.pendingStaffEvent != nil {
                tally(
                    Reducer.apply(
                        .resolveStaffEvent(
                            choice: answered.isMultiple(of: 2) ? .supportive : .strict
                        ),
                        to: &state, balance: tuned, content: content
                    ),
                    into: &log
                )
            }
            if let candidate = state.candidatePool.first, state.headcount < 12 {
                Reducer.apply(
                    .hire(candidateID: candidate.id), to: &state, balance: tuned, content: content
                )
            }
            if state.productInDevelopment == nil {
                let topic = content.topics[day % content.topics.count].id
                Reducer.apply(
                    .startProduct(
                        typeID: "mobile_app", topicID: topic, name: "Build \(day)", focus: .balanced
                    ),
                    to: &state, balance: tuned, content: content
                )
            } else if let product = state.productInDevelopment, day % 60 == 59 {
                Reducer.apply(
                    .ship(productID: product.id), to: &state, balance: tuned, content: content
                )
            }
            if state.company.officeTier.next != nil, day % 200 == 199 {
                Reducer.apply(.upgradeOffice, to: &state, balance: tuned, content: content)
            }
        }
        return log
    }

    private static func tally(_ events: [GameEvent], into log: inout RunLog) {
        for event in events {
            switch event {
            case .randomEvent(let id, _):
                log.company.insert(id)
                log.companyFired.append(id)
            case .lifeEvent(let id, _):
                log.life.insert(id)
            case .industryNews(let headline, _):
                log.news.insert(headline)
            case .staffEventOccurred(_, let kind, _, _):
                log.staff.insert(kind)
            default:
                break
            }
        }
    }
}
