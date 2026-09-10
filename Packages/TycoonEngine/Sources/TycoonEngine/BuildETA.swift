import Foundation
import TycoonContent

/// When a build will be done, at today's crew, focus, pace and tech.
///
/// A product in development records what it has, never when it will have
/// the rest: the three pools fill, and the only clock on screen was the
/// player's own sense of how fast the bars move. The war room's countdown
/// and the agenda's ETA row both need a date, so this projects one from
/// exactly the arithmetic `EmployeeSystem` will apply tomorrow — the crew's
/// pool yields, the tech multiplier, Brooks's crowding and the pace —
/// divided into what each pool still needs.
///
/// A pure projection: it reads the state, draws nothing and moves nothing.
/// It is also honest about being a projection — skills grow, the founder
/// tires, someone quits — so the day it names is the day *if nothing
/// changes*, which is the only kind of ETA there is.
public struct BuildETA: Equatable, Sendable {
    /// Points landing in each pool per day at today's crew and focus, after
    /// the tech, crowding and pace multipliers.
    public var designPerDay: Double
    public var codePerDay: Double
    public var polishPerDay: Double

    /// Points each pool still needs; 0 when it is full.
    public var designRemaining: Double
    public var codeRemaining: Double
    public var polishRemaining: Double

    /// Whole days until every pool that is being worked is full; 0 when
    /// the build is done. `nil` when nothing is moving — nobody is on the
    /// build, or the focus has abandoned every pool that still needs work.
    public var daysToComplete: Int?

    /// Whole days until the code pool passes the ship threshold; 0 when it
    /// could ship today. `nil` when it is not there yet and no code is
    /// landing.
    public var daysToShippable: Int?

    /// How many people are producing on the build today, the founder
    /// included unless they are away.
    public var crewCount: Int

    /// Whether every pool is full.
    public var isComplete: Bool {
        designRemaining <= 0 && codeRemaining <= 0 && polishRemaining <= 0
    }

    /// The absolute day the build completes, counted from `day`.
    public func completionDay(from day: Int) -> Int? {
        daysToComplete.map { day + $0 }
    }

    /// Whole days for `remaining` points at `rate` per day: 0 when there
    /// is nothing left, `nil` when nothing is landing.
    static func days(remaining: Double, rate: Double) -> Int? {
        if remaining <= 0 { return 0 }
        guard rate > 0 else { return nil }
        return Int((remaining / rate).rounded(.up))
    }
}

extension GameState {
    /// Projects when `productID` will be done. `nil` for anything not in
    /// development or whose type the catalog does not know.
    public func buildETA(
        productID: UUID,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> BuildETA? {
        guard let product = product(id: productID),
              case .development(let dev) = product.stage,
              let type = content.productType(product.typeID)
        else { return nil }

        // The same crew, the same multipliers `EmployeeSystem.buildProduct`
        // applies, so the rate here is the rate tomorrow's tick will use.
        let crew = EmployeeSystem.gatherCrewOutput(
            productID: productID, focus: dev.focus,
            state: self, balance: balance, content: content
        )
        let pace = balance.economy.pace(economy.workPace)
        let output = devSpeedTechMultiplier(content: content)
            // MARK: K3 (the ladder) — the same relief the tick applies.
            * ladderCrowdingFactor(producers: crew.producers, balance: balance)
            // MARK: end K3
            * pace.outputFactor

        let designPerDay = crew.design * output
        let codePerDay = crew.code * output
        let polishPerDay = crew.polish * output

        let designRemaining = max(0, type.designPts - dev.designPts)
        let codeRemaining = max(0, type.codePts - dev.codePts)
        let polishRemaining = max(0, type.polishPts - dev.polishPts)

        // Every pool that is moving names its own day; the build is done
        // on the latest of them. A pool that still needs points but gets
        // none is not counted — it is stalled, not slow — and a build where
        // nothing moves at all has no date.
        let perPool: [(remaining: Double, rate: Double)] = [
            (designRemaining, designPerDay),
            (codeRemaining, codePerDay),
            (polishRemaining, polishPerDay),
        ]
        let moving = perPool.compactMap { BuildETA.days(remaining: $0.remaining, rate: $0.rate) }
        let anyMoving = perPool.contains { $0.rate > 0 }
        let daysToComplete: Int? = anyMoving ? moving.max() : (perPool.allSatisfy { $0.remaining <= 0 } ? 0 : nil)

        let shipRemaining = max(0, balance.shipCodeThreshold * type.codePts - dev.codePts)

        return BuildETA(
            designPerDay: designPerDay,
            codePerDay: codePerDay,
            polishPerDay: polishPerDay,
            designRemaining: designRemaining,
            codeRemaining: codeRemaining,
            polishRemaining: polishRemaining,
            daysToComplete: daysToComplete,
            daysToShippable: BuildETA.days(remaining: shipRemaining, rate: codePerDay),
            crewCount: crew.producers.count
        )
    }
}
