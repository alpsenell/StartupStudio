import Foundation
import Testing
import TycoonContent
import TycoonEngine

/// The codebase: the head start, the debt, and the assignment that pays it
/// back.
///
/// The load-bearing test in here is the first one. Everything else in this
/// feature is allowed to be retuned; `greenfieldIsExactlyWhatItAlwaysWas`
/// is the promise that no amount of retuning can reach the shipped pacing
/// table, and it is asserted on the *shipped* balance rather than a
/// neutralised one on purpose.
@Suite("The codebase")
struct CodebaseTests {
    /// The shipped codebase block on top of a test economy that keeps the
    /// crew ceiling (this suite is about a second ceiling underneath it)
    /// and switches the bug roll off, so pool arithmetic is exact.
    private static func balance(bugChanceBase: Double = 0) -> BalanceConfig {
        var economy = TestBalance.neutralEconomy
        economy.qualityCeilingBase = 0.35
        var balance = TestBalance.make(
            bugChanceBase: bugChanceBase,
            candidateRefreshDays: 10_000,
            contractOfferRefreshDays: 10_000,
            eventCheckIntervalDays: 10_000,
            life: TestBalance.quietLife,
            economy: economy
        )
        balance.codebase = .default
        return balance
    }

    private static func content() -> ContentCatalog {
        TestContent.tiny(designPts: 40, codePts: 40, polishPts: 40)
    }

    private static func newGame(_ balance: BalanceConfig) -> GameState {
        GameState.newGame(companyName: "Acme", seed: 12, balance: balance)
    }

    /// Builds `name` from `codebaseID` (nil = greenfield) and ticks until
    /// it ships or `limit` days pass. Returns the state and the day it
    /// shipped on.
    @discardableResult
    private static func buildAndShip(
        name: String,
        on codebaseID: String?,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog,
        limit: Int = 400
    ) -> (productID: UUID, daysTaken: Int)? {
        let start: GameAction = codebaseID.map {
            .startProductOnCodebase(
                typeID: "tool", topicID: "testing", name: name, focus: .balanced, codebaseID: $0
            )
        } ?? .startProduct(typeID: "tool", topicID: "testing", name: name, focus: .balanced)
        Reducer.apply(start, to: &state, balance: balance, content: content)
        guard let product = state.productsInDevelopment.last else { return nil }
        // `startProduct` only recruits the *idle*, and straight after a
        // ship the crew is still nominally on the product they shipped
        // (the sweep idles them on the next tick). Put them on it by hand
        // so the two arms of the comparison start with the same people.
        for employee in state.employees {
            Reducer.apply(
                .assign(employeeID: employee.id, to: .product(product.id)),
                to: &state, balance: balance, content: content
            )
        }
        let startDay = state.day

        for _ in 0..<limit {
            Reducer.tick(&state, balance: balance, content: content)
            guard let forecast = state.shipForecast(
                productID: product.id, balance: balance, content: content
            ) else { break }
            // Ship the moment every pool is full — the point of comparison
            // is how long the pools took, not how patient a bot is.
            if case .development(let dev) = state.product(id: product.id)?.stage,
               dev.designPts >= 40, dev.codePts >= 40, dev.polishPts >= 40, forecast.canShip {
                Reducer.apply(
                    .ship(productID: product.id), to: &state, balance: balance, content: content
                )
                return (product.id, state.day - startDay)
            }
        }
        return nil
    }

    // MARK: - The invariant

    @Test("A greenfield build is exactly what it always was")
    func greenfieldIsExactlyWhatItAlwaysWas() throws {
        let balance = Self.balance()
        let codebase = balance.codebase

        // The two multipliers this feature introduces, at their shipped
        // defaults, on a build with no codebase. Both read 1.0 to the bit.
        #expect(codebase.debtCeiling(0) == 1.0)
        #expect(codebase.bugRateMultiplier(0) == 1.0)

        var state = Self.newGame(balance)
        Reducer.apply(
            .startProduct(typeID: "tool", topicID: "testing", name: "T", focus: .balanced),
            to: &state, balance: balance, content: Self.content()
        )
        let product = try #require(state.productInDevelopment)
        #expect(product.codebaseID == nil)
        guard case .development(let dev) = product.stage else { return }
        #expect(dev.designPts == 0)
        #expect(dev.codePts == 0)
        #expect(dev.polishPts == 0)
        #expect(state.inheritedDebt(for: product) == 0)

        let forecast = try #require(
            state.shipForecast(productID: product.id, balance: balance, content: Self.content())
        )
        #expect(forecast.codebaseCeiling == 1.0)
        #expect(forecast.codebaseDebt == 0)
        #expect(forecast.codebaseName == nil)
    }

    @Test("The debt a build creates never touches the build that created it")
    func accruedDebtIsInertUntilShip() throws {
        let balance = Self.balance()
        let content = Self.content()
        var state = Self.newGame(balance)
        Reducer.apply(.setWorkPace(.crunch), to: &state, balance: balance, content: content)
        Reducer.apply(
            .startProduct(typeID: "tool", topicID: "testing", name: "Crunched", focus: .balanced),
            to: &state, balance: balance, content: content
        )
        let id = try #require(state.productInDevelopment).id
        for _ in 0..<20 { Reducer.tick(&state, balance: balance, content: content) }

        guard case .development(let dev) = try #require(state.product(id: id)).stage else { return }
        #expect(dev.debtAccrued > 0, "twenty crunch days left no mess behind")
        // ...and none of it reaches this product's own numbers.
        let forecast = try #require(
            state.shipForecast(productID: id, balance: balance, content: content)
        )
        #expect(forecast.codebaseCeiling == 1.0)
        #expect(state.inheritedDebt(for: try #require(state.product(id: id))) == 0)
    }

    // MARK: - What a ship leaves behind

    @Test("Shipping leaves a codebase carrying part of the pools")
    func shippingLeavesACodebase() throws {
        let balance = Self.balance()
        let content = Self.content()
        var state = Self.newGame(balance)
        #expect(state.codebases.isEmpty)

        _ = Self.buildAndShip(
            name: "First", on: nil, state: &state, balance: balance, content: content
        )

        let codebase = try #require(state.codebases.first)
        #expect(state.codebases.count == 1)
        #expect(codebase.id == "tool")
        #expect(codebase.name == "First")
        #expect(codebase.productsShipped == 1)
        // The pools carry at `carryFraction` of what the product filled,
        // clamped to the type's own pools (all three were full).
        let carried = 40 * balance.codebase.carryFraction
        #expect(abs(codebase.designPts - carried) < 1e-9)
        #expect(abs(codebase.codePts - carried) < 1e-9)
        #expect(abs(codebase.polishPts - carried) < 1e-9)
        // Nothing crunched and nothing shipped broken, so it is clean.
        #expect(codebase.debt == 0)
    }

    @Test("Building on it starts weeks ahead")
    func theHeadStartIsWeeks() throws {
        let balance = Self.balance()
        let content = Self.content()

        var greenfield = Self.newGame(balance)
        let first = try #require(Self.buildAndShip(
            name: "First", on: nil, state: &greenfield, balance: balance, content: content
        ))
        let codebase = try #require(greenfield.codebases.first)

        // The same studio, on the same day, building the same thing twice:
        // once from scratch, once on what it just shipped.
        var fromScratch = greenfield
        let second = try #require(Self.buildAndShip(
            name: "Second", on: nil, state: &fromScratch, balance: balance, content: content
        ))
        var onCodebase = greenfield
        let inherited = try #require(Self.buildAndShip(
            name: "Second", on: codebase.id,
            state: &onCodebase, balance: balance, content: content
        ))

        #expect(inherited.daysTaken < second.daysTaken,
                "building on \(codebase.name) saved nothing")
        // The head start is a real fraction of the build, not a rounding
        // error — this is what the player is being offered.
        #expect(Double(inherited.daysTaken) < Double(second.daysTaken) * 0.85)
        // And the pools genuinely started part-full.
        let onIt = try #require(onCodebase.product(id: inherited.productID))
        #expect(onIt.codebaseID == "tool")
        _ = first
    }

    @Test("A codebase of the wrong type is no head start at all")
    func aMismatchedCodebaseIsGreenfield() throws {
        let balance = Self.balance()
        let content = Self.content()
        var state = Self.newGame(balance)
        state.codebases = [Codebase(
            id: "some_other_type", name: "Elsewhere",
            designPts: 40, codePts: 40, polishPts: 40, debt: 50
        )]

        Reducer.apply(
            .startProductOnCodebase(
                typeID: "tool", topicID: "testing", name: "T", focus: .balanced,
                codebaseID: "some_other_type"
            ),
            to: &state, balance: balance, content: content
        )
        let product = try #require(state.productInDevelopment)
        #expect(product.codebaseID == nil)
        guard case .development(let dev) = product.stage else { return }
        #expect(dev.codePts == 0)
    }

    // MARK: - Where debt comes from

    @Test("Crunch and open bugs both land on the codebase at ship")
    func crunchAndBugsBecomeDebt() throws {
        let balance = Self.balance()
        let content = Self.content()

        var calm = Self.newGame(balance)
        _ = Self.buildAndShip(
            name: "Calm", on: nil, state: &calm, balance: balance, content: content
        )
        #expect(try #require(calm.codebases.first).debt == 0)

        var crunched = Self.newGame(balance)
        Reducer.apply(.setWorkPace(.crunch), to: &crunched, balance: balance, content: content)
        _ = Self.buildAndShip(
            name: "Crunched", on: nil, state: &crunched, balance: balance, content: content
        )
        let debt = try #require(crunched.codebases.first).debt
        #expect(debt > 0, "a whole build under crunch left a spotless codebase")
    }

    @Test("Bugs shipped are debt inherited")
    func shippedBugsAreDebt() throws {
        // Same build, same seed, with the bug roll on: whatever is still
        // open at ship is charged at `shipBugDebt` a bug.
        let balance = Self.balance(bugChanceBase: 1.0)
        let content = Self.content()
        var state = Self.newGame(balance)

        Reducer.apply(
            .startProduct(typeID: "tool", topicID: "testing", name: "Buggy", focus:
                PhaseFocus(design: 0.5, code: 0.5, polish: 0)),
            to: &state, balance: balance, content: content
        )
        let id = try #require(state.productInDevelopment).id
        while true {
            Reducer.tick(&state, balance: balance, content: content)
            guard case .development(let dev) = try #require(state.product(id: id)).stage
            else { break }
            if dev.codePts >= 40 { break }
        }
        guard case .development(let dev) = try #require(state.product(id: id)).stage else { return }
        try #require(dev.openBugs > 0)
        let expected = Double(dev.openBugs) * balance.codebase.shipBugDebt

        Reducer.apply(.ship(productID: id), to: &state, balance: balance, content: content)
        let debt = try #require(state.codebases.first).debt
        #expect(abs(debt - expected) < 1e-9)
    }

    // MARK: - Refactoring

    @Test("Refactoring cuts debt and lifts the ceiling of the build in flight")
    func refactoringPaysOffImmediately() throws {
        let balance = Self.balance()
        let content = Self.content()
        var state = Self.newGame(balance)
        state.codebases = [Codebase(id: "tool", name: "Legacy", debt: 60)]

        Reducer.apply(
            .startProductOnCodebase(
                typeID: "tool", topicID: "testing", name: "Rescue", focus: .balanced,
                codebaseID: "tool"
            ),
            to: &state, balance: balance, content: content
        )
        let id = try #require(state.productInDevelopment).id
        let before = try #require(
            state.shipForecast(productID: id, balance: balance, content: content)
        )
        #expect(before.codebaseDebt == 60)
        #expect(before.codebaseCeiling < 1)

        // The founder walks off the build and onto the codebase.
        let founder = try #require(state.employees.first { $0.isFounder })
        Reducer.apply(
            .assign(employeeID: founder.id, to: .refactor("tool")),
            to: &state, balance: balance, content: content
        )
        for _ in 0..<30 { Reducer.tick(&state, balance: balance, content: content) }

        let after = try #require(
            state.shipForecast(productID: id, balance: balance, content: content)
        )
        #expect(after.codebaseDebt < before.codebaseDebt)
        #expect(after.codebaseCeiling > before.codebaseCeiling,
                "thirty days of refactoring bought no ceiling back")
        // The debt cannot be refactored below zero.
        for _ in 0..<400 { Reducer.tick(&state, balance: balance, content: content) }
        #expect(try #require(state.codebase(id: "tool")).debt == 0)
    }

    @Test("Refactorers produce nothing anyone can see")
    func refactorersProduceNothing() throws {
        let balance = Self.balance()
        let content = Self.content()
        var state = Self.newGame(balance)
        state.codebases = [Codebase(id: "tool", name: "Legacy", debt: 40)]

        Reducer.apply(
            .startProductOnCodebase(
                typeID: "tool", topicID: "testing", name: "Stalled", focus: .balanced,
                codebaseID: "tool"
            ),
            to: &state, balance: balance, content: content
        )
        let id = try #require(state.productInDevelopment).id
        let founder = try #require(state.employees.first { $0.isFounder })
        Reducer.apply(
            .assign(employeeID: founder.id, to: .refactor("tool")),
            to: &state, balance: balance, content: content
        )
        guard case .development(let before) = try #require(state.product(id: id)).stage
        else { return }

        for _ in 0..<20 { Reducer.tick(&state, balance: balance, content: content) }

        guard case .development(let after) = try #require(state.product(id: id)).stage
        else { return }
        #expect(after.designPts == before.designPts)
        #expect(after.codePts == before.codePts)
        #expect(after.polishPts == before.polishPts)
        #expect(after.hype == before.hype)
        // And nobody drifted off the desk on their own.
        #expect(state.employees.first { $0.isFounder }?.assignment == .refactor("tool"))
    }

    @Test("A refactor desk on a codebase that isn't there is swept to idle")
    func staleRefactorAssignmentsAreSwept() throws {
        let balance = Self.balance()
        let content = Self.content()
        var state = Self.newGame(balance)
        let founder = try #require(state.employees.first { $0.isFounder })
        Reducer.apply(
            .assign(employeeID: founder.id, to: .refactor("nothing_here")),
            to: &state, balance: balance, content: content
        )
        Reducer.tick(&state, balance: balance, content: content)
        #expect(state.employees.first { $0.isFounder }?.assignment == .idle)
    }

    // MARK: - What the sheet says

    @Test("The ship sheet names the codebase when the codebase is the cap")
    func theSheetNamesTheCodebase() throws {
        let balance = Self.balance()
        let content = Self.content()
        var state = Self.newGame(balance)
        // A studio full of very good people on a very bad codebase: the
        // crew is not the problem and the sheet must not say it is.
        state.codebases = [Codebase(
            id: "tool", name: "Legacy",
            designPts: 40, codePts: 40, polishPts: 40, debt: 90
        )]
        for index in state.employees.indices {
            state.employees[index].skills = SkillSet(coding: 100, design: 100, marketing: 100)
        }
        Reducer.apply(
            .startProductOnCodebase(
                typeID: "tool", topicID: "testing", name: "Doomed", focus: .balanced,
                codebaseID: "tool"
            ),
            to: &state, balance: balance, content: content
        )
        let id = try #require(state.productInDevelopment).id
        for _ in 0..<40 { Reducer.tick(&state, balance: balance, content: content) }

        let forecast = try #require(
            state.shipForecast(productID: id, balance: balance, content: content)
        )
        #expect(forecast.codebaseName == "Legacy")
        #expect(forecast.codebaseCeiling < forecast.skillCeiling)
        let factor = try #require(forecast.limitingFactor)
        #expect(factor.hasPrefix("The codebase caps this at "))
        #expect(factor.contains("\(Int((forecast.crewCeiling * 100).rounded()))"))
    }

    @Test("The forecast still quotes the quality the launch produces")
    func theForecastStillTellsTheTruthOnACodebase() throws {
        let balance = Self.balance()
        let content = Self.content()
        var state = Self.newGame(balance)
        state.codebases = [Codebase(
            id: "tool", name: "Legacy",
            designPts: 20, codePts: 20, polishPts: 20, debt: 45
        )]
        Reducer.apply(
            .startProductOnCodebase(
                typeID: "tool", topicID: "testing", name: "Heir", focus: .balanced,
                codebaseID: "tool"
            ),
            to: &state, balance: balance, content: content
        )
        let id = try #require(state.productInDevelopment).id
        for _ in 0..<80 { Reducer.tick(&state, balance: balance, content: content) }

        let forecast = try #require(
            state.shipForecast(productID: id, balance: balance, content: content)
        )
        try #require(forecast.canShip)
        Reducer.apply(.ship(productID: id), to: &state, balance: balance, content: content)
        guard case .released(let info) = try #require(state.product(id: id)).stage else { return }
        #expect(abs(info.quality - forecast.quality) < 1e-9)
    }

    // MARK: - Saves

    @Test("Codebases survive a save round-trip")
    func codebasesRoundTrip() throws {
        let balance = Self.balance()
        let content = Self.content()
        var state = Self.newGame(balance)
        _ = Self.buildAndShip(
            name: "First", on: nil, state: &state, balance: balance, content: content
        )
        Reducer.apply(
            .startProductOnCodebase(
                typeID: "tool", topicID: "testing", name: "Second", focus: .balanced,
                codebaseID: "tool"
            ),
            to: &state, balance: balance, content: content
        )
        let founder = try #require(state.employees.first { $0.isFounder })
        Reducer.apply(
            .assign(employeeID: founder.id, to: .refactor("tool")),
            to: &state, balance: balance, content: content
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(GameState.self, from: data)
        #expect(decoded == state)
        #expect(decoded.codebases == state.codebases)
        #expect(decoded.products.map(\.codebaseID) == state.products.map(\.codebaseID))
        #expect(decoded.employees.first { $0.isFounder }?.assignment == .refactor("tool"))
    }

    @Test("A save with no codebases decodes as a studio that has never shipped")
    func aSaveWithoutCodebasesReadsAsGreenfield() throws {
        let balance = Self.balance()
        let content = Self.content()
        var state = Self.newGame(balance)
        Reducer.apply(
            .startProduct(typeID: "tool", topicID: "testing", name: "InFlight", focus: .balanced),
            to: &state, balance: balance, content: content
        )
        for _ in 0..<20 { Reducer.tick(&state, balance: balance, content: content) }

        // Strip the keys this feature added, the way a save written before
        // it existed would never have had them.
        var json = try #require(
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(state))
                as? [String: Any]
        )
        json.removeValue(forKey: "codebases")
        var products = try #require(json["products"] as? [[String: Any]])
        for index in products.indices {
            products[index].removeValue(forKey: "codebaseID")
            if var stage = products[index]["stage"] as? [String: Any],
               var development = stage["development"] as? [String: Any],
               var progress = development["_0"] as? [String: Any] {
                progress.removeValue(forKey: "debtAccrued")
                development["_0"] = progress
                stage["development"] = development
                products[index]["stage"] = stage
            }
        }
        json["products"] = products

        let decoded = try JSONDecoder().decode(
            GameState.self,
            from: try JSONSerialization.data(withJSONObject: json)
        )
        #expect(decoded.codebases.isEmpty)
        let product = try #require(decoded.productInDevelopment)
        #expect(product.codebaseID == nil)
        #expect(decoded.inheritedDebt(for: product) == 0)
        guard case .development(let dev) = product.stage else { return }
        #expect(dev.debtAccrued == 0)
        // It carries on ticking as the greenfield build it always was.
        var resumed = decoded
        Reducer.tick(&resumed, balance: balance, content: content)
        let forecast = try #require(
            resumed.shipForecast(productID: product.id, balance: balance, content: content)
        )
        #expect(forecast.codebaseCeiling == 1.0)
    }
}
