import Foundation
import TycoonContent
import TycoonEngine

// J5 "how it fails" check (scratch, not a test): does a build ship by the
// ETA taken at 50% progress? Plays a simple studio bot through the real
// reducer on the shipped balance, and for every build records the ship-gate
// ETA (what `ShipETA` and the announce sheet use) at 25% and 50% of the
// way to the gate, then the day the gate actually opened and the day every
// pool filled.

let balance = try BalanceConfig.loadBundled()
let content = try ContentCatalog.loadBundled()

struct Sample {
    var type: String
    var crewAt50: Int = 0
    var day50: Int?
    var gateETA50: Int?
    var doneETA50: Int?
    var day25: Int?
    var gateETA25: Int?
    var gateDay: Int?
    var doneDay: Int?
}

func run(seed: UInt64, days: Int, crewCap: Int, types: [String]) -> [Sample] {
    var state = GameState.newGame(
        companyName: "Check", seed: seed, balance: balance, origin: .garage, content: content
    )
    var samples: [UUID: Sample] = [:]
    for _ in 0..<days {
        _ = Reducer.tick(&state, balance: balance, content: content)
        if state.gameOver != nil { break }

        var actions: [GameAction] = []
        if state.headcount < crewCap, state.company.cash > 25_000, let c = state.candidatePool.first {
            actions.append(.hire(candidateID: c.id))
        }
        if let next = state.company.officeTier.next,
           state.company.cash >= balance.office(next).upgradeCost + 15_000 {
            actions.append(.upgradeOffice)
        }
        if let product = state.productInDevelopment,
           case .development(let dev) = product.stage,
           let type = content.productType(product.typeID) {
            let gate = balance.shipCodeThreshold * type.codePts
            var s = samples[product.id] ?? Sample(type: product.typeID)
            let progress = dev.codePts / gate
            if s.day25 == nil, progress >= 0.25 {
                s.day25 = state.day
                s.gateETA25 = state.shipETA(for: product, balance: balance, content: content)?.day
            }
            if s.day50 == nil, progress >= 0.5 {
                s.day50 = state.day
                s.gateETA50 = state.shipETA(for: product, balance: balance, content: content)?.day
                let eta = state.buildETA(productID: product.id, balance: balance, content: content)
                s.doneETA50 = eta?.completionDay(from: state.day)
                s.crewAt50 = eta?.crewCount ?? 0
            }
            if s.gateDay == nil, dev.codePts >= gate { s.gateDay = state.day }
            let done = dev.designPts >= type.designPts && dev.codePts >= type.codePts
                && dev.polishPts >= type.polishPts
            if done {
                s.doneDay = state.day
                actions.append(.ship(productID: product.id))
            } else {
                for e in state.employees where e.assignment != .product(product.id) {
                    actions.append(.assign(employeeID: e.id, to: .product(product.id)))
                }
            }
            samples[product.id] = s
        } else if state.company.cash > 20_000 {
            let type = types[state.products.count % types.count]
            actions.append(.startProduct(
                typeID: type, topicID: "fitness", name: "Check \(state.products.count + 1)", focus: .balanced
            ))
        } else {
            var target = state.activeContracts.first?.id
            if target == nil, let best = state.contractOffers
                .filter({ $0.penalty <= state.company.cash }).max(by: { $0.payout < $1.payout }) {
                actions.append(.acceptContract(offerID: best.id))
                target = best.id
            }
            if let target {
                for e in state.employees where e.assignment != .contract(target) {
                    actions.append(.assign(employeeID: e.id, to: .contract(target)))
                }
            }
        }
        for a in actions { _ = Reducer.apply(a, to: &state, balance: balance, content: content) }
    }
    return samples.values.filter { $0.doneDay != nil && $0.gateETA50 != nil }
}

func pct(_ n: Int, _ d: Int) -> String { d == 0 ? "-" : "\(Int((Double(n) / Double(d) * 100).rounded()))%" }
func median(_ xs: [Int]) -> Int { xs.isEmpty ? 0 : xs.sorted()[xs.count / 2] }

let minLead = balance.announce.minLeadDays
for (label, cap, types) in [
    ("solo founder, mobile/web", 1, ["mobile_app", "web_app"]),
    ("crew of 3, mobile/web", 3, ["mobile_app", "web_app"]),
    ("crew of 6, mobile/web/desktop", 6, ["mobile_app", "web_app", "desktop_tool"]),
] {
    var all: [Sample] = []
    for seed in 1...30 { all += run(seed: UInt64(seed), days: 3 * 364, crewCap: cap, types: types) }
    let n = all.count
    let gateErr = all.map { $0.gateDay! - $0.gateETA50! }
    let doneErr = all.compactMap { s in s.doneETA50.map { s.doneDay! - $0 } }
    let left50 = all.map { $0.gateETA50! - $0.day50! }
    print("== \(label): \(n) builds over 30 seeds × 3 years")
    print("   days from 50% to the gate ETA: median \(median(left50)); under \(minLead) (too close to announce): \(pct(left50.filter { $0 < minLead }.count, n))")
    print("   gate day − gate ETA@50: median \(median(gateErr)), max \(gateErr.max() ?? 0), min \(gateErr.min() ?? 0)")
    for slack in [0, 7, 14] {
        print("   gate by ETA@50 + \(slack): \(pct(gateErr.filter { $0 <= slack }.count, n))")
    }
    // What the sheet actually offers at 50%: max(day + minLead, ETA + slack).
    for slack in [0, 14] {
        let hits = all.filter { s in s.gateDay! <= max(s.day50! + minLead, s.gateETA50! + slack) }.count
        let doneHits = all.filter { s in s.doneDay! <= max(s.day50! + minLead, s.gateETA50! + slack) }.count
        print("   announced at 50% with slack \(slack) (sheet date): gate on time \(pct(hits, n)), full build on time \(pct(doneHits, n))")
    }
    // Under the early rule: only builds whose gate ETA was >= 14 days out at 50%.
    let early14 = all.filter { $0.gateETA50! - $0.day50! >= 14 }
    for slack in [0, 7, 14, 28] {
        let hits = early14.filter { s in s.gateDay! <= max(s.day50! + minLead, s.gateETA50! + slack) }.count
        print("   early rule (ETA >= 14 at 50%, \(early14.count) builds), slack \(slack): gate on time \(pct(hits, early14.count))")
    }
    print("   full build − completion ETA@50: median \(median(doneErr)), max \(doneErr.max() ?? 0)")
    let early = all.filter { $0.gateETA25 != nil }
    let hits25 = early.filter { s in s.gateDay! <= max(s.day25! + minLead, s.gateETA25! + 14) }.count
    let err25 = early.map { $0.gateDay! - $0.gateETA25! }
    print("   at 25%: gate − ETA median \(median(err25)), max \(err25.max() ?? 0); sheet date (slack 14) on time \(pct(hits25, early.count))")
}
