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
    // Iteration 11, wave two (W2): a `var`, so the will can append the one
    // sentence that says it was named.
    var relation: String

    // MARK: Iteration 9 — L3 (a childhood, carried)

    /// Trait ids the household grew: two burnouts make a Grumbler, a
    /// house full of launch nights makes a Speedster, a summer at the
    /// studio makes a Mentor. Empty for a successor who is not a child.
    var householdTraits: [String] = []
    /// The one line that says why: "Grew up through two burnouts and an
    /// eviction." Empty when there is nothing on the ledger.
    var upbringing: String?

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
                // Iteration 9 (L3): what they saw growing up decides who
                // they are. A child with no ledger — every child from a
                // run recorded before this round — falls back to the
                // appearance-seed archetype the dynasty always used.
                let upbringing = Upbringing(child: child)
                offers.append(Successor(
                    run: run, kind: .child,
                    name: surname.isEmpty ? child.name : "\(child.name) \(surname)",
                    appearanceSeed: child.appearanceSeed,
                    archetype: upbringing.archetype
                        ?? FounderArchetype.allCases[Int(child.appearanceSeed % 3)],
                    relation: [
                        "Child of \(run.founderName), who ran \(run.companyName).",
                        upbringing.line,
                        upbringing.traitLine,
                    ].compactMap { $0 }.joined(separator: " "),
                    householdTraits: upbringing.traits,
                    upbringing: upbringing.line
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
        // MARK: Iteration 11, wave two — W2 (family drama)
        // A will names one of them. The named person keeps their own offer
        // and moves to the front of the list, with the reason said out
        // loud — nothing here is a new kind of successor, only an order
        // and a sentence.
        offers = FamilyWillSuccessors.namedFirst(offers, in: last)
        // MARK: end of Iteration 11, wave two — W2
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

    // MARK: Iteration 9 — L3 (household-grown traits)

    /// A childhood read off the memory ledger: the traits it grew, the
    /// archetype it points at, and the sentence that says why.
    ///
    /// This is the "child grown from the household" iteration 8 promised
    /// and left undone. Nothing here is random: the same ledger always
    /// produces the same person.
    struct Upbringing {
        var traits: [String] = []
        var archetype: FounderArchetype?
        var line: String?

        init(child: LegacyChild) {
            var counts: [ChildMemoryKind: Int] = [:]
            for memory in child.memories {
                guard let kind = ChildMemoryKind(rawValue: memory.kind) else { continue }
                counts[kind, default: 0] += 1
            }
            guard !counts.isEmpty || child.internSummers > 0 else { return }

            var clauses: [String] = []
            // A house that fell apart twice teaches you to expect it.
            let hard = (counts[.burnout] ?? 0) + (counts[.hospital] ?? 0) + (counts[.eviction] ?? 0)
            if hard >= 2 {
                traits.append("grumbler")
                clauses.append("\(Self.count(hard)) bad year\(hard == 1 ? "" : "s")")
            }
            // A house that shipped teaches you that shipping is normal.
            let launches = (counts[.launch] ?? 0) + (counts[.chapter] ?? 0)
            if launches >= 2 {
                traits.append("speedster")
                clauses.append("\(Self.count(launches)) launch nights")
                archetype = .hacker
            }
            // A summer at the studio teaches you how to teach.
            if child.internSummers > 0 || counts[.internSummer] != nil {
                traits.append("mentor")
                clauses.append(child.internSummers > 1
                    ? "\(Self.count(child.internSummers)) summers at the studio"
                    : "a summer at the studio")
                archetype = archetype ?? .hustler
            }
            // Evenings that were theirs, and birthdays that were kept.
            let kept = (counts[.evening] ?? 0) + (counts[.birthdayKept] ?? 0)
            if kept >= 3 || child.bond >= 75 {
                traits.append("loyalist")
                clauses.append("a parent who turned up")
            }
            if (counts[.missedBirthday] ?? 0) >= 2 {
                traits.append("loner")
                clauses.append("two birthdays spent waiting")
            }
            if counts[.exit] != nil {
                archetype = archetype ?? .hustler
                clauses.append("the day it was sold")
            }
            guard !clauses.isEmpty else { return }
            line = "Grew up through \(Self.sentence(clauses))."
        }

        /// "Reads as: Speedster, Mentor." — the traits the household grew,
        /// named the way the Team tab names an employee's.
        var traitLine: String? {
            guard !traits.isEmpty else { return nil }
            return "Reads as: \(traits.map(Self.displayName).joined(separator: ", "))."
        }

        /// The trait id as the rest of the game writes it. Kept local
        /// rather than read from `Traits.json` so a successor row never
        /// waits on the catalog.
        private static func displayName(_ id: String) -> String {
            switch id {
            case "grumbler": "Grumbler"
            case "speedster": "Speedster"
            case "mentor": "Mentor"
            case "loyalist": "Loyalist"
            case "loner": "Loner"
            default: id.capitalized
            }
        }

        private static func count(_ n: Int) -> String {
            switch n {
            case ..<2: "one"
            case 2: "two"
            case 3: "three"
            case 4: "four"
            default: "\(n)"
            }
        }

        /// "a, b and c" — the clause list as one readable phrase.
        private static func sentence(_ clauses: [String]) -> String {
            guard clauses.count > 1 else { return clauses[0] }
            return clauses.dropLast().joined(separator: ", ") + " and " + clauses[clauses.count - 1]
        }
    }

    /// The lineage's one line for the biography.
    static func line(for lineage: Lineage, companyName: String? = nil) -> String {
        // MARK: K5 (hand over the keys)
        // The same company, carried on by somebody who worked there: a
        // hand-over, not a new founding.
        if lineage.kind == .employee, let companyName, companyName == lineage.predecessorCompanyName {
            return "Took the keys to \(companyName) from \(lineage.predecessorFounderName)."
        }
        // MARK: end K5
        return switch lineage.kind {
        case .child: "Child of \(lineage.predecessorFounderName), who ran \(lineage.predecessorCompanyName)."
        case .employee: "Started out at \(lineage.predecessorCompanyName), under \(lineage.predecessorFounderName)."
        case .founder: "Second time around: \(lineage.predecessorCompanyName) was the first."
        }
    }
}

// MARK: Iteration 11, wave two — W2 (family drama)

/// The will's half of the dynasty: whoever the founder named is offered
/// first, and the relation line says the will did it.
enum FamilyWillSuccessors {
    static func namedFirst(_ offers: [Successor], in run: LegacyRun) -> [Successor] {
        guard let heir = run.willHeir.flatMap(FamilyHeir.init(rawValue:)), heir != .nobody
        else { return offers }
        let namedChild = (run.children ?? []).first { $0.id == run.willHeirChildID }
        func isNamed(_ successor: Successor) -> Bool {
            switch heir {
            case .child:
                // Matched by the child's own name rather than the offer's,
                // because an offer carries the founder's surname and the
                // will does not.
                guard let namedChild else { return false }
                return successor.kind == .child && successor.name.hasPrefix(namedChild.name)
            case .employee:
                return successor.kind == .employee
            case .partner, .sibling, .nobody:
                // Neither is a successor the ledger carries; the will is
                // recorded and the biography says so, and that is all.
                return false
            }
        }
        guard let index = offers.firstIndex(where: isNamed) else { return offers }
        var reordered = offers
        var chosen = reordered.remove(at: index)
        chosen.relation += " Named in \(run.founderName)'s will."
        reordered.insert(chosen, at: 0)
        return reordered
    }
}

// MARK: end of Iteration 11, wave two — W2
