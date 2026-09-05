import Foundation
import TycoonEngine

#if DEBUG
// MARK: Iteration 7 — a ledger for the screenshot pass (R2)

extension LegacyLedger {
    /// Two finished companies, for `-autoHeirlooms`: three people, two
    /// perks and a studio's deed on the table. Debug builds only.
    static let sample: LegacyLedger = {
        func person(_ index: Int, _ name: String, coding: Double, design: Double, marketing: Double,
                    rapport: Double, role: EmployeeRole, traits: [String]) -> LegacyPerson {
            LegacyPerson(
                id: UUID(uuidString: String(format: "5A4D9E00-0000-4000-8000-%012d", index))!,
                name: name, appearanceSeed: 0x5EED_00A0 &+ UInt64(index) &* 2_654_435_761,
                skills: SkillSet(coding: coding, design: design, marketing: marketing),
                revealedTraits: traits, rapport: rapport, role: role
            )
        }
        var ledger = LegacyLedger()
        ledger.runs = [
            LegacyRun(
                id: UUID(uuidString: "5A4D9E00-0000-4000-8000-00000000A001")!,
                companyName: "Northgate Softworks", founderName: "Mira Okafor", seed: 4_242,
                origin: .garage, difficulty: .normal, ending: .ipo, day: 1_180, founderNetWorth: 8_400_000,
                people: [
                    person(1, "Marco Reyes", coding: 82, design: 34, marketing: 20, rapport: 91, role: .backend, traits: ["speedster", "mentor"]),
                    person(2, "Priya Natarajan", coding: 28, design: 79, marketing: 41, rapport: 74, role: .designer, traits: ["perfectionist"]),
                ],
                perks: ["pressContacts", "talentMagnet"],
                deed: LegacyDeed(tier: .studio, district: .midtown)
            ),
            LegacyRun(
                id: UUID(uuidString: "5A4D9E00-0000-4000-8000-00000000A002")!,
                companyName: "Rooftop Labs", founderName: "Dev Anand", seed: 77,
                origin: .cofounded, difficulty: .hard, ending: .bankruptcy, day: 402, founderNetWorth: -12_000,
                people: [
                    person(3, "Tomasz Wilk", coding: 45, design: 30, marketing: 77, rapport: 58, role: .marketer, traits: []),
                ],
                perks: ["pressContacts"],
                deed: nil
            ),
        ]
        ledger.endingsReached = [.ipo, .bankruptcy]
        return ledger
    }()
}
#endif
