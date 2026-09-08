import Foundation
import TycoonEngine

#if DEBUG
/// A game advanced to a live product with people around it, and an
/// incident of the asked-for kind already raised (iteration 10, M3).
///
/// `simctl` can launch the app and take its picture but cannot tap it, and
/// an incident by construction needs a shipped product, a staffed office
/// and a player who has opened the Products tab — none of which a headless
/// launch has. So `-autoIncident <kind>` plays the engine's own game to a
/// release, opens the room by hand through the reducer, and hands the
/// result to `AppRootView`. Deterministic, like `WarRoomFixture`: a fixed
/// seed, the reducer ticked day by day.
enum IncidentFixture {
    /// The most ticks the fixture will spend getting a product on the
    /// market and a few people around it.
    private static let tickCap = 900

    @MainActor
    static func engine(_ kind: IncidentKind, seed: UInt64 = 7_711) -> GameEngine? {
        let fresh = GameEngine.newGame(
            companyName: "Northgate Softworks",
            seed: seed,
            difficulty: .normal,
            founder: FounderProfile(name: "Mira Okafor", archetype: .hacker, appearanceSeed: 0x5EED)
        )
        let balance = fresh.balance
        let content = fresh.content
        var state = fresh.state

        // The same shape of play as `WarRoomFixture`: one product, the
        // focus re-aimed at what the build needs, shipped as soon as the
        // pools are full, then a few weeks on the market so it has sales
        // to lose — and a handful of hires, so the board has people on it.
        guard let type = content.productTypes.first(where: {
            state.isProductTypeUnlocked($0.id, content: content)
        }) else { return nil }
        let topic = content.topics.max { ($0.fitByType[type.id] ?? 1) < ($1.fitByType[type.id] ?? 1) }
            ?? content.topics[0]
        Reducer.apply(
            .startProduct(typeID: type.id, topicID: topic.id, name: "Overcast", focus: .matching(type: type)),
            to: &state, balance: balance, content: content
        )
        guard let productID = state.productInDevelopment?.id else { return nil }

        var shipped = false
        var weeksOnMarket = 0
        var released: Product?
        for _ in 0..<tickCap {
            // Hire whoever is going, up to a room worth photographing.
            if state.headcount < 4,
               let candidate = state.candidatePool.first,
               state.company.cash > candidate.weeklySalary * 12 {
                Reducer.apply(.hire(candidateID: candidate.id), to: &state, balance: balance, content: content)
                if let hire = state.employees.last, !hire.isFounder {
                    Reducer.apply(
                        .assign(employeeID: hire.id, to: shipped ? .support(productID) : .product(productID)),
                        to: &state, balance: balance, content: content
                    )
                }
            }
            if !shipped, case .development(let dev)? = state.product(id: productID)?.stage {
                Reducer.apply(
                    .setPhaseFocus(productID: productID, focus: .matching(progress: dev, type: type)),
                    to: &state, balance: balance, content: content
                )
                if state.buildETA(productID: productID, balance: balance, content: content)?.isComplete == true {
                    Reducer.apply(.ship(productID: productID), to: &state, balance: balance, content: content)
                    shipped = true
                }
            }
            Reducer.tick(&state, balance: balance, content: content)
            if state.gameOver != nil { return nil }
            if shipped, state.day % GameState.daysPerWeek == 0 { weeksOnMarket += 1 }
            released = state.products.first { product in
                guard case .released(let info) = product.stage else { return false }
                return !info.offMarket && info.weeklySales.count >= 3
            }
            if released != nil, weeksOnMarket >= 4, state.headcount >= 3 { break }
        }
        guard let product = released,
              let index = state.products.firstIndex(where: { $0.id == product.id }),
              case .released(var info) = state.products[index].stage
        else { return nil }

        // The facts the kind needs, written straight onto the release: this
        // is a screenshot fixture, not a simulation of how one is earned.
        switch kind {
        case .badPatch:
            info.liveBugs = max(info.liveBugs, balance.economy.liveBugAlarmThreshold + 6)
            info.lastUpdateDay = state.day
            info.updateCount += 1
        case .viralSpike:
            if let last = info.weeklySales.last {
                info.weeklySales.append(
                    WeeklySale(
                        weekIndex: last.weekIndex + 1,
                        units: max(600, last.units * 3),
                        revenue: max(600, last.revenue * 3)
                    )
                )
            }
        case .dataLeak:
            info.subscribers = max(info.subscribers, 900)
        }
        state.products[index].stage = .released(info)

        // The room itself, through the reducer, so it is the room the
        // player would get.
        state.economy.incidents.hasOpenedProducts = true
        state.incident = IncidentState(
            productID: product.id,
            kind: kind,
            startedDay: state.day,
            reach: max(
                IncidentSystem.reach(of: info),
                balance.incidents.minimumReach
            )
        )
        state.speed = .paused
        return GameEngine.resume(state: state)
    }
}

/// `-autoIncident <kind>`: the room a headless pass asked for, and the
/// hours it should work before the picture is taken.
enum IncidentDebug {
    /// The kind named on the command line, if any.
    @MainActor
    static var requestedKind: IncidentKind? {
        guard let name = DebugLaunch.value(after: "-autoIncident")?.lowercased() else { return nil }
        return IncidentKind.allCases.first { $0.rawValue.lowercased() == name }
    }

    /// Consumed once per launch, so a redraw does not re-open the room.
    @MainActor private static var consumed = false

    /// The engine the flag asks for, once.
    @MainActor
    static func launchEngine() -> GameEngine? {
        guard !consumed, let kind = requestedKind else { return nil }
        consumed = true
        return IncidentFixture.engine(kind)
    }

    @MainActor private static var autoplayed = false

    /// Whether the headless pass wants the room scrolled to the statement.
    @MainActor
    static var scrollsToStatement: Bool {
        ProcessInfo.processInfo.arguments.contains("-autoIncidentScroll")
    }

    /// `-autoIncidentPlay`: staffs the three lanes, works two hours and
    /// picks the honest statement, so the screenshot is of a room in
    /// progress rather than one nobody has touched.
    @MainActor
    static func autoplayIfAsked(engine: GameEngine) {
        guard !autoplayed,
              ProcessInfo.processInfo.arguments.contains("-autoIncidentPlay"),
              let incident = engine.state.incident
        else { return }
        autoplayed = true
        let roster = engine.state.employees.sorted { lhs, rhs in
            if lhs.isFounder != rhs.isFounder { return lhs.isFounder }
            return lhs.hiredDay < rhs.hiredDay
        }
        let lanes = IncidentThread.allCases
        for (offset, employee) in roster.enumerated() {
            engine.send(
                .assignToIncident(employeeID: employee.id, thread: lanes[offset % lanes.count])
            )
        }
        engine.send(.advanceIncident)
        engine.send(.advanceIncident)
        engine.send(.advanceIncident)
        let statements = IncidentStatements.all(
            for: incident.kind,
            productName: engine.state.product(id: incident.productID)?.name ?? ""
        )
        if let first = statements.first {
            engine.send(.chooseIncidentStatement(id: first.id))
        }
        // `-autoIncidentClose` carries on and closes it, so the outcome —
        // the toast, the journal line, the front page — can be
        // photographed too.
        if ProcessInfo.processInfo.arguments.contains("-autoIncidentClose") {
            Task {
                try? await Task.sleep(for: .seconds(3))
                engine.send(.resolveIncident)
            }
        }
    }
}
#endif
