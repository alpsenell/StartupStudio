import Foundation
import TycoonContent

// MARK: K2 (product lifecycle)

#if DEBUG
/// Iteration 15 — K2. `-autoRoute k2-…`: dresses a save so the lifecycle's
/// surfaces can be photographed without hands. Reached only through
/// `.lifecycleDebug`, which only `DebugLaunch` sends and only in debug
/// builds.
enum LifecycleDebugSeed {
    static func apply(
        scenario: String,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        switch scenario {
        case "successor":
            return seedSuccessor(state: &state, content: content)
        case "solvent":
            // The studio fixture has four weeks of runway: a pass that
            // lets a week go by would photograph the bankruptcy warning
            // instead of the paper.
            state.company.cash += 500_000
            return []
        default:
            return []
        }
    }

    /// A ship-ready v2 of the live product with the biggest book (Round 6
    /// on the studio fixture): same type and topic, pools nearly full, a
    /// decent crew's average on record. Bypasses the slot cap on purpose;
    /// a screenshot needs the build, not the wait.
    private static func seedSuccessor(state: inout GameState, content: ContentCatalog) -> [GameEvent] {
        let parent = state.products
            .filter { $0.releaseInfo.map { !$0.offMarket } ?? false }
            .max { ($0.releaseInfo?.subscribers ?? 0) < ($1.releaseInfo?.subscribers ?? 0) }
        guard let parent, let type = content.productType(parent.typeID),
              !state.products.contains(where: { $0.name == "\(parent.name) v2" })
        else { return [] }
        let id = UUID(from: &state.rng)
        state.products.append(Product(
            id: id,
            name: "\(parent.name) v2",
            typeID: parent.typeID,
            topicID: parent.topicID,
            stage: .development(DevProgress(
                designPts: type.designPts,
                codePts: type.codePts * 0.95,
                polishPts: type.polishPts * 0.9,
                openBugs: 2,
                focus: .balanced,
                hype: 20,
                crewSkillDaySum: 72 * 30,
                crewSkillDays: 30
            )),
            codebaseID: state.codebase(id: parent.typeID)?.id
        ))
        return [.productStarted(productID: id, day: state.day)]
    }
}
#endif

// MARK: end K2
