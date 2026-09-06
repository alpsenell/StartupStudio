import Foundation
import TycoonEngine

// MARK: Iteration 8 — the dynasty

/// Somebody the ledger offers as the next founder: the last founder's
/// child grown up, the last company's longest-serving employee, or the
/// same founder, older.
struct Successor: Identifiable {
    let run: LegacyRun
    let kind: SuccessorKind
    let name: String
    let appearanceSeed: UInt64
    let archetype: FounderArchetype
    /// "Child of Mira Okafor, who ran Northgate."
    let relation: String

    var id: String { "\(run.id.uuidString)-\(kind.rawValue)-\(name)" }

    var lineage: Lineage {
        Lineage(
            predecessorRunID: run.id, predecessorFounderName: run.founderName,
            predecessorCompanyName: run.companyName, kind: kind
        )
    }
}

enum Successors {
    /// The successors the most recent company offers. Empty on a fresh
    /// install, and empty for a ledger written before the dynasty.
    static func offers(from ledger: LegacyLedger) -> [Successor] {
        guard let last = ledger.runs.last else { return [] }
        var offers: [Successor] = []
        // Children from every company — a family outlasts one firm.
        for run in ledger.runs {
            let surname = run.founderName.split(separator: " ").last.map(String.init) ?? ""
            for child in run.children ?? [] {
                offers.append(Successor(
                    run: run, kind: .child,
                    name: surname.isEmpty ? child.name : "\(child.name) \(surname)",
                    appearanceSeed: child.appearanceSeed,
                    archetype: FounderArchetype.allCases[Int(child.appearanceSeed % 3)],
                    relation: "Child of \(run.founderName), who ran \(run.companyName)."
                ))
            }
        }
        if let employee = last.longestServing {
            offers.append(Successor(
                run: last, kind: .employee,
                name: employee.name,
                appearanceSeed: employee.appearanceSeed,
                archetype: archetype(for: employee.resolvedRole),
                relation: "\(last.companyName)'s longest-serving \(employee.resolvedRole.displayName.lowercased())."
            ))
        }
        if let seed = last.founderAppearanceSeed, let archetype = last.founderArchetype {
            offers.append(Successor(
                run: last, kind: .founder,
                name: last.founderName,
                appearanceSeed: seed,
                archetype: archetype,
                relation: "\(last.founderName), again — older, and \(last.ending.isSuccess ? "richer" : "wiser")."
            ))
        }
        return offers
    }

    static func archetype(for role: EmployeeRole) -> FounderArchetype {
        switch role {
        case .frontend, .backend, .qa: .hacker
        case .designer: .designer
        default: .hustler
        }
    }

    /// The lineage's one line for the biography.
    static func line(for lineage: Lineage) -> String {
        switch lineage.kind {
        case .child: "Child of \(lineage.predecessorFounderName), who ran \(lineage.predecessorCompanyName)."
        case .employee: "Started out at \(lineage.predecessorCompanyName), under \(lineage.predecessorFounderName)."
        case .founder: "Second time around: \(lineage.predecessorCompanyName) was the first."
        }
    }
}
