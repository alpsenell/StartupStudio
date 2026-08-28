import Foundation
import Testing
import TycoonContent
@testable import TycoonEngine

/// The three trait effects that had no consumer until this pass:
/// `hypeMult` (how far a campaign carries), `bugMult` (how careful the crew
/// at the keyboard is) and `crunchMoraleMult` (how hard a crunch week lands
/// on one person).
///
/// Every hook is written so that a roster with no traits the catalog knows,
/// or a content bundle that authors none of the three, goes through exactly
/// the arithmetic it did before. That identity is what keeps
/// `FullLoopDeterminismTests` and the balance suites byte-identical, so it
/// is asserted first and directly.
@Suite("Trait hooks: hype, bugs, crunch")
struct TraitHookTests {
    // MARK: - Test content

    /// A catalog shaped exactly like `TestContent.tiny`, plus a hand-built
    /// trait table. Every trait here moves *one* field, so a test measuring
    /// bugs cannot be reading an output change by accident.
    private static func catalog(
        traits: [TraitDef],
        designPts: Double = 1_000,
        codePts: Double = 1_000,
        polishPts: Double = 1_000,
        techTree: [TechNode] = []
    ) -> ContentCatalog {
        let tiny = TestContent.tiny(
            designPts: designPts, codePts: codePts, polishPts: polishPts, techTree: techTree
        )
        return ContentCatalog(
            productTypes: tiny.productTypes,
            topics: tiny.topics,
            techTree: tiny.techTree,
            events: tiny.events,
            names: tiny.names,
            lifeEvents: tiny.lifeEvents,
            traits: traits
        )
    }

    private static func trait(_ id: String, _ effects: TraitDef.Effects) -> TraitDef {
        TraitDef(id: id, name: id, blurb: "A test trait.", effects: effects)
    }

    /// A real, catalogued trait that does nothing — the "no personality"
    /// marker. `Employee.init` derives two traits from the appearance seed
    /// whenever the list handed to it is empty, so an *explicit* inert id is
    /// the only way to say "this person has no traits" and mean it.
    private static let plain = trait("plain", .neutral)
    private static let loud = trait("loud", TraitDef.Effects(hypeMult: 1.5))
    private static let quiet = trait("quiet", TraitDef.Effects(hypeMult: 0.8))
    private static let careless = trait("careless", TraitDef.Effects(bugMult: 2.0))
    private static let careful = trait("careful", TraitDef.Effects(bugMult: 0.5))
    private static let brittle = trait("brittle", TraitDef.Effects(crunchMoraleMult: 1.5))
    private static let steady = trait("steady", TraitDef.Effects(crunchMoraleMult: 0.5))

    private static let allTraits = [plain, loud, quiet, careless, careful, brittle, steady]

    private static func person(
        _ traits: [String] = ["plain"],
        role: EmployeeRole = .backend,
        coding: Double = 50,
        marketing: Double = 0,
        salary: Int = 500,
        assignment: Assignment = .idle
    ) -> Employee {
        Employee(
            id: UUID(),
            name: "Test",
            skills: SkillSet(coding: coding, design: 25, marketing: marketing),
            weeklySalary: salary,
            assignment: assignment,
            isFounder: false,
            hiredDay: 0,
            appearanceSeed: 7,
            role: role,
            traits: traits
        )
    }

    // MARK: - Identity

    /// The whole safety argument in one test: with an inert personality, or
    /// with a catalog that has never heard of the traits somebody carries,
    /// all three hooks are exactly 1.
    @Test func everyHookIsIdentityWithoutTraits() {
        let content = Self.catalog(traits: Self.allTraits)
        let bare = Self.person()
        #expect(TraitEffects.hypeFactor(bare, content: content) == 1)
        #expect(TraitEffects.bugFactor(bare, content: content) == 1)
        #expect(TraitEffects.crunchMoraleFactor(bare, content: content) == 1)

        // Traits the catalog does not know are skipped, not guessed at.
        let stranger = Self.person(["loud", "careless", "brittle"])
        let emptyCatalog = Self.catalog(traits: [])
        #expect(TraitEffects.hypeFactor(stranger, content: emptyCatalog) == 1)
        #expect(TraitEffects.bugFactor(stranger, content: emptyCatalog) == 1)
        #expect(TraitEffects.crunchMoraleFactor(stranger, content: emptyCatalog) == 1)
    }

    /// A trait that only authors one of the three leaves the other two, and
    /// all eight older fields, exactly where they were.
    @Test func oneFieldMovesAtATime() {
        let content = Self.catalog(traits: Self.allTraits)
        let marketer = Self.person(["loud"])
        #expect(TraitEffects.hypeFactor(marketer, content: content) == 1.5)
        #expect(TraitEffects.bugFactor(marketer, content: content) == 1)
        #expect(TraitEffects.crunchMoraleFactor(marketer, content: content) == 1)
        #expect(TraitEffects.outputFactor(marketer, content: content) == 1)
        #expect(TraitEffects.growthFactor(marketer, content: content) == 1)
        #expect(TraitEffects.moraleTargetDelta(marketer, content: content) == 0)
        #expect(TraitEffects.quitStreakBonus(marketer, content: content) == 0)
        #expect(TraitEffects.poachResistance(marketer, content: content) == 1)
    }

    // MARK: - Combination and clamps

    @Test func twoTraitsMultiplyAndAreClamped() {
        let content = Self.catalog(traits: Self.allTraits)
        // 1.5 × 0.8 lands inside the band.
        #expect(abs(TraitEffects.hypeFactor(
            Self.person(["loud", "quiet"]), content: content
        ) - 1.2) < 1e-12)

        // 1.5 × 1.5 = 2.25, clamped to the hype ceiling.
        #expect(TraitEffects.hypeFactor(
            Self.person(["loud", "loud"]), content: content
        ) == TraitEffects.Limits.hypeMultMax)

        // 2.0 × 2.0 = 4, clamped; 0.5 × 0.5 = 0.25, clamped.
        #expect(TraitEffects.bugFactor(
            Self.person(["careless", "careless"]), content: content
        ) == TraitEffects.Limits.bugMultMax)
        #expect(TraitEffects.bugFactor(
            Self.person(["careful", "careful"]), content: content
        ) == TraitEffects.Limits.bugMultMin)

        #expect(TraitEffects.crunchMoraleFactor(
            Self.person(["steady", "steady"]), content: content
        ) == TraitEffects.Limits.crunchMoraleMultMin)
    }

    // MARK: - Crew aggregates

    @Test func campaignHypeIsTheMeanOfTheMarketers() {
        let content = Self.catalog(traits: Self.allTraits)
        #expect(TraitEffects.campaignHypeFactor([], content: content) == 1)

        // Nobody in marketing: the founder's press release is unchanged,
        // however loud the engineers are.
        let engineers = [Self.person(["loud"]), Self.person(["loud"])]
        #expect(TraitEffects.campaignHypeFactor(engineers, content: content) == 1)

        let one = [Self.person(["loud"], role: .marketer)]
        #expect(TraitEffects.campaignHypeFactor(one, content: content) == 1.5)

        // Mean, not product: a second marketer does not double the shout.
        let pair = one + [Self.person(["quiet"], role: .marketer)]
        #expect(abs(TraitEffects.campaignHypeFactor(pair, content: content) - 1.15) < 1e-12)

        // And an engineer in the room does not dilute it.
        #expect(abs(TraitEffects.campaignHypeFactor(
            pair + engineers, content: content
        ) - 1.15) < 1e-12)
    }

    @Test func crewBugFactorIsTheMeanOfWhoWroteTheCode() {
        let content = Self.catalog(traits: Self.allTraits)
        #expect(TraitEffects.crewBugFactor([], content: content) == 1)
        #expect(TraitEffects.crewBugFactor([Self.person(["careful"])], content: content) == 0.5)
        // (2.0 + 0.5) / 2
        #expect(abs(TraitEffects.crewBugFactor(
            [Self.person(["careless"]), Self.person(["careful"])], content: content
        ) - 1.25) < 1e-12)
        // A plain pair of hands pulls the crew back toward 1.
        #expect(abs(TraitEffects.crewBugFactor(
            [Self.person(["careless"]), Self.person()], content: content
        ) - 1.5) < 1e-12)
    }

    // MARK: - hypeMult in MarketingSystem

    /// A press release costs the same and lands harder with a showman
    /// running it — and is untouched when nobody is in marketing.
    @Test func aMarketersTraitsScaleTheOneShotCampaigns() throws {
        func hype(marketerTraits: [String]?) throws -> Double {
            let balance = TestBalance.make(life: TestBalance.quietLife)
            let content = Self.catalog(
                traits: Self.allTraits,
                techTree: [
                    TestTech.node(
                        id: "press_kit", researchCost: 10,
                        effect: .unlockCampaignKind(id: "press_release")
                    )
                ]
            )
            var state = GameState.newGame(companyName: "Acme", seed: 3, balance: balance)
            state.research.unlocked.insert("press_kit")
            state.company.cash = 50_000
            if let traits = marketerTraits {
                state.employees.append(Self.person(traits, role: .marketer))
            }
            Reducer.apply(
                .startProduct(typeID: "tool", topicID: "testing", name: "T", focus: .balanced),
                to: &state, balance: balance, content: content
            )
            let productID = try #require(state.productInDevelopment?.id)
            Reducer.apply(
                .startCampaign(kindID: "press_release", productID: productID),
                to: &state, balance: balance, content: content
            )
            guard case .development(let dev) = try #require(state.product(id: productID)).stage
            else {
                Issue.record("expected the product to still be in development")
                throw CancellationError()
            }
            return dev.hype
        }

        let base = try hype(marketerTraits: nil)
        #expect(base == TestBalance.make().pressReleaseHype)
        #expect(abs(try hype(marketerTraits: ["loud"]) - base * 1.5) < 1e-9)
        #expect(abs(try hype(marketerTraits: ["quiet"]) - base * 0.8) < 1e-9)
        // A plain marketer changes nothing at all.
        #expect(try hype(marketerTraits: ["plain"]) == base)
    }

    /// The same factor rides the daily social-push hype.
    @Test func aMarketersTraitsScaleTheDailySocialPush() throws {
        func hypeAfterADay(marketerTraits: [String]?) throws -> Double {
            let balance = TestBalance.make(skillGrowthRate: 0, life: TestBalance.quietLife)
            let content = Self.catalog(traits: Self.allTraits)
            var state = GameState.newGame(companyName: "Acme", seed: 4, balance: balance)
            state.company.cash = 50_000
            if let traits = marketerTraits {
                state.employees.append(Self.person(traits, role: .marketer))
            }
            Reducer.apply(
                .startProduct(typeID: "tool", topicID: "testing", name: "T", focus: .balanced),
                to: &state, balance: balance, content: content
            )
            let productID = try #require(state.productInDevelopment?.id)
            Reducer.apply(
                .startCampaign(kindID: "social_push", productID: productID),
                to: &state, balance: balance, content: content
            )
            Reducer.tick(&state, balance: balance, content: content)
            guard case .development(let dev) = try #require(state.product(id: productID)).stage
            else {
                Issue.record("expected the product to still be in development")
                throw CancellationError()
            }
            return dev.hype
        }

        // The push is the only hype in play: the marketer is idle, so they
        // add none of their own and the whole difference is the factor.
        let base = try hypeAfterADay(marketerTraits: nil)
        #expect(base > 0)
        #expect(try hypeAfterADay(marketerTraits: ["plain"]) == base)
        #expect(try hypeAfterADay(marketerTraits: ["loud"]) > base)
        #expect(try hypeAfterADay(marketerTraits: ["quiet"]) < base)
    }

    /// A marketer assigned to a product also carries their factor into the
    /// daily hype `EmployeeSystem` credits them with.
    @Test func anAssignedMarketersOwnHypeCarriesTheirTraits() throws {
        func hypeAfterADay(traits: [String]) throws -> Double {
            var company = TestBalance.neutralCompany
            company.marketerDailyHype = 0.4  // the shipped figure
            let balance = TestBalance.make(
                skillGrowthRate: 0, life: TestBalance.quietLife, company: company
            )
            let content = Self.catalog(traits: Self.allTraits)
            var state = GameState.newGame(companyName: "Acme", seed: 6, balance: balance)
            Reducer.apply(
                .startProduct(typeID: "tool", topicID: "testing", name: "T", focus: .balanced),
                to: &state, balance: balance, content: content
            )
            let productID = try #require(state.productInDevelopment?.id)
            state.employees.append(Self.person(
                traits, role: .marketer, marketing: 50, assignment: .product(productID)
            ))
            Reducer.tick(&state, balance: balance, content: content)
            guard case .development(let dev) = try #require(state.product(id: productID)).stage
            else {
                Issue.record("expected the product to still be in development")
                throw CancellationError()
            }
            return dev.hype
        }

        let base = try hypeAfterADay(traits: ["plain"])
        #expect(base > 0)
        #expect(abs(try hypeAfterADay(traits: ["loud"]) - base * 1.5) < 1e-9)
        #expect(abs(try hypeAfterADay(traits: ["quiet"]) - base * 0.8) < 1e-9)
    }

    // MARK: - bugMult in ProductSystem

    /// Bug rolls draw one uniform per completed code point whatever the
    /// chance is, so the runs below consume the same RNG stream and the only
    /// difference is who was at the keyboard.
    @Test func aCarelessCrewShipsMoreBugsThanACarefulOne() throws {
        func bugs(crewTraits: [String]) throws -> Int {
            let balance = TestBalance.make(
                bugChanceBase: 0.4, bugChanceSkillDivisor: 1e9, skillGrowthRate: 0,
                life: TestBalance.quietLife
            )
            let content = Self.catalog(traits: Self.allTraits, codePts: 5_000)
            var state = GameState.newGame(companyName: "Acme", seed: 11, balance: balance)
            TestLife.pinPeak(&state)
            state.company.cash = 500_000
            Reducer.apply(
                .startProduct(
                    typeID: "tool", topicID: "testing", name: "T",
                    focus: PhaseFocus(design: 0, code: 1, polish: 0)
                ),
                to: &state, balance: balance, content: content
            )
            let productID = try #require(state.productInDevelopment?.id)
            // Two hired hands, so the trait-less founder is not the whole
            // crew and the mean actually moves.
            for _ in 0..<2 {
                state.employees.append(Self.person(
                    crewTraits, coding: 60, assignment: .product(productID)
                ))
            }
            for _ in 0..<30 {
                Reducer.tick(&state, balance: balance, content: content)
            }
            guard case .development(let dev) = try #require(state.product(id: productID)).stage
            else {
                Issue.record("expected the product to still be in development")
                throw CancellationError()
            }
            return dev.openBugs
        }

        let neutral = try bugs(crewTraits: ["plain"])
        #expect(neutral > 0, "the fixture needs bugs to be possible at all")
        #expect(try bugs(crewTraits: ["careless"]) > neutral)
        #expect(try bugs(crewTraits: ["careful"]) < neutral)
    }

    /// And with nobody carrying a trait the catalog knows, the founder
    /// writes exactly the bugs the pre-hook engine did.
    @Test func aTraitlessCrewIsUntouched() throws {
        func bugs(_ content: ContentCatalog) throws -> Int {
            let balance = TestBalance.make(
                bugChanceBase: 0.4, bugChanceSkillDivisor: 1e9, skillGrowthRate: 0,
                life: TestBalance.quietLife
            )
            var state = GameState.newGame(companyName: "Acme", seed: 12, balance: balance)
            TestLife.pinPeak(&state)
            Reducer.apply(
                .startProduct(
                    typeID: "tool", topicID: "testing", name: "T",
                    focus: PhaseFocus(design: 0, code: 1, polish: 0)
                ),
                to: &state, balance: balance, content: content
            )
            let productID = try #require(state.productInDevelopment?.id)
            for _ in 0..<30 {
                Reducer.tick(&state, balance: balance, content: content)
            }
            guard case .development(let dev) = try #require(state.product(id: productID)).stage
            else {
                Issue.record("expected the product to still be in development")
                throw CancellationError()
            }
            return dev.openBugs
        }
        let withTraitTable = try bugs(Self.catalog(traits: Self.allTraits, codePts: 5_000))
        let withoutOne = try bugs(Self.catalog(traits: [], codePts: 5_000))
        #expect(withTraitTable == withoutOne)
    }

    // MARK: - crunchMoraleMult in EmployeeSystem

    /// Crunch takes 18 points off the morale target. A brittle person loses
    /// 27, a steady one 9, and a plain one still loses exactly 18.
    @Test func crunchLandsDifferentlyOnDifferentPeople() throws {
        func moraleUnder(_ pace: WorkPace, traits: [String]) -> Double {
            var economy = TestBalance.neutralEconomy
            economy.pace = BalanceConfig.EconomyBalance.PaceDef.standardTable
            economy.stagnationDays = 364
            var staff = BalanceConfig.StaffBalance.standard
            staff.moraleAdaptRate = 1  // snap to the target in one tick
            staff.quitStreakDays = 1_000_000
            let balance = TestBalance.make(
                life: TestBalance.quietLife, staff: staff, economy: economy
            )
            let content = Self.catalog(traits: Self.allTraits)
            var state = GameState.newGame(companyName: "Acme", seed: 41, balance: balance)
            TestLife.pinPeak(&state)
            state.economy.workPace = pace
            state.employees.append(Self.person(traits, salary: 2_000))
            Reducer.tick(&state, balance: balance, content: content)
            return state.employees.last?.morale ?? 0
        }

        let normal = moraleUnder(.normal, traits: ["plain"])
        #expect(abs(moraleUnder(.crunch, traits: ["plain"]) - (normal - 18)) < 1e-9)
        #expect(abs(moraleUnder(.crunch, traits: ["brittle"]) - (normal - 27)) < 1e-9)
        #expect(abs(moraleUnder(.crunch, traits: ["steady"]) - (normal - 9)) < 1e-9)

        // A relaxed week is good for everybody: the multiplier only weighs a
        // penalty, so a brittle person still gets the whole +6.
        let relaxed = moraleUnder(.relaxed, traits: ["plain"])
        #expect(abs(relaxed - (normal + 6)) < 1e-9)
        #expect(abs(moraleUnder(.relaxed, traits: ["brittle"]) - relaxed) < 1e-9)
        #expect(abs(moraleUnder(.relaxed, traits: ["steady"]) - relaxed) < 1e-9)
        // And at a normal pace the trait is inert.
        #expect(abs(moraleUnder(.normal, traits: ["brittle"]) - normal) < 1e-9)
    }

    // MARK: - The shipped bundle

    /// `Traits.json` does not author the three new fields yet, so the shipped
    /// game is exactly the game it was. This test is the tripwire: when the
    /// balance pass authors them the hooks go live, which is a real balance
    /// change, and the harness table has to be re-recorded in the same edit.
    @Test func theShippedCatalogStillAuthorsNoneOfTheThree() {
        for def in TestContent.bundled.traits {
            #expect(
                def.effects.hypeMult == 1 && def.effects.bugMult == 1
                    && def.effects.crunchMoraleMult == 1,
                """
                \(def.id) now authors hypeMult/bugMult/crunchMoraleMult. The \
                hooks are live, so this is a real balance change: re-run the \
                balance harness and update its recorded table.
                """
            )
        }
    }
}
