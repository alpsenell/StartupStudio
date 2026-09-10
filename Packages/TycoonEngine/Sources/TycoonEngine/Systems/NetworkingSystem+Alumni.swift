import Foundation
import TycoonContent

/// What happens to the people who leave.
///
/// Leaving used to be deletion: a quit, a firing or a successful poach
/// removed the employee and everything the founder had built with them.
/// Now anyone who leaves becomes — or re-opens as — a contact, with the
/// same id and face, the skills they had, the traits the founder already
/// knows, and a rapport equal to the bond they left with. They keep moving
/// off-screen, and the returning-faces slot a room already has is where
/// the founder runs into them again.
///
/// Nothing here draws. The contact is built from the employee and the
/// day; the off-screen drift is arithmetic on the calendar; a founding
/// takes its name from the person's own surname and its valuation from
/// their skills. A run in which nobody leaves has a byte-identical
/// `socialRNG` stream, and the pacing suite — which never opens a room —
/// cannot see any of it.
extension NetworkingSystem {
    /// Tuning that is design rather than balance: none of these numbers
    /// can be felt by a bot, so they live beside the code that uses them
    /// the way `RivalDepthTuning` does.
    enum AlumniTuning {
        /// What a departing employee asks for, over fair pay, unless a
        /// rival already named a number.
        static let askOverFairPay = 1.1
        /// A firing at a bond below this leaves at rapport zero, closed.
        static let burnedBondThreshold = 30.0
        /// Skill points gained per quarter away.
        static let skillPointsPerQuarter = 3.0
        static let quarterDays = 91
        /// Days away before a prodigy or a showman has founded something.
        static let foundingDays = 180
        /// Valuation per skill point of the person, clamped to the range a
        /// stranger's startup rolls in.
        static let foundingValuationPerSkillPoint = 1_500
        static let foundingValuationRange = 40_000...600_000
        /// The traits that go and start something.
        static let founderTraits: Set<String> = ["prodigy", "showman"]
        static let companySuffixes = ["Labs", "Systems", "Works", "Studio", "Software", "& Co"]
    }

    /// Puts somebody who just left payroll into the address book. Called
    /// from the three exits — the quit path, `EmployeeSystem.fire` and
    /// `RivalSystem.poachSucceeds` — after the employee is off the roster.
    ///
    /// Their ask is the rival's number if they were poached, otherwise fair
    /// pay and ten percent; their rapport is the bond they left with; and
    /// the founder already knows what they want (`isRevealed`) and how
    /// they feel about the company (`interest` is their morale on the way
    /// out — somebody who quit miserable needs the pitch again). A firing
    /// at a bond under `burnedBondThreshold` closes them as `.lost`: you
    /// burned them, and they stay in the book only as history.
    ///
    /// Someone who was a contact before they were hired re-opens under the
    /// same entry, keeping the archetype and the company they had.
    static func departed(
        _ employee: Employee,
        reason: DepartureReason,
        poachOffer: Int? = nil,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard !employee.isFounder else { return [] }
        let burned = reason == .fired && employee.founderBond < AlumniTuning.burnedBondThreshold
        let ask: Int = if reason == .poached, let poachOffer {
            poachOffer
        } else {
            Int((EmployeeSystem.fairWeeklyPay(for: employee, balance: balance)
                * AlumniTuning.askOverFairPay).rounded())
        }
        let rapport = burned ? 0 : min(100, max(0, employee.founderBond))
        let interest = min(100, max(0, employee.morale))
        let outcome: ContactOutcome? = burned ? .lost : nil

        if let index = state.networking.contacts.firstIndex(where: { $0.id == employee.id }) {
            var contact = state.networking.contacts[index]
            contact.name = employee.name
            contact.skills = employee.skills
            contact.askingSalary = ask
            contact.rapport = rapport
            contact.interest = interest
            contact.lastMetDay = state.day
            contact.isRevealed = true
            contact.outcome = outcome
            contact.leftDay = state.day
            contact.leftReason = reason
            contact.leftRole = employee.role
            state.networking.contacts[index] = contact
        } else {
            state.networking.contacts.append(Contact(
                id: employee.id,
                name: employee.name,
                appearanceSeed: employee.appearanceSeed,
                archetype: employee.role.contactArchetype,
                skills: employee.skills,
                askingSalary: ask,
                rapport: rapport,
                interest: interest,
                metDay: employee.hiredDay,
                lastMetDay: state.day,
                isRevealed: true,
                outcome: outcome,
                leftDay: state.day,
                leftReason: reason,
                leftRole: employee.role
            ))
        }
        // The book keeps its cap; the person who just walked out is the
        // one entry it must not evict to do so.
        trimContacts(&state, balance, protecting: [employee.id])
        // MARK: K3 (the ladder)
        // Unvested options come home; what vested leaves with them — to a
        // rival, if that is where they went. Nothing for a non-holder.
        let settled = EmployeeSystem.ladderSettleOptions(employee, state: &state, balance: balance)
        // MARK: end K3
        return [.alumnusJoinedBook(contactID: employee.id, name: employee.name, day: state.day)]
            + settled
    }

    /// Daily: former employees keep moving. Every quarter away adds
    /// `skillPointsPerQuarter` to the thing they do for a living, and
    /// after `foundingDays` a prodigy or a showman has founded something —
    /// they get a company and a valuation, and `backThem` opens. Open
    /// alumni only: the ones who are history stay history.
    static func driftAlumni(_ state: inout GameState) {
        for index in state.networking.contacts.indices {
            let contact = state.networking.contacts[index]
            guard contact.isOpen, let leftDay = contact.leftDay, state.day > leftDay else { continue }
            let away = state.day - leftDay

            if away % AlumniTuning.quarterDays == 0 {
                state.networking.contacts[index].skills = grown(contact.skills, role: contact.leftRole)
                // MARK: Iteration 9 — L1 (phone)
                // The boomerang: every quarter away, they check in. Text
                // only — nothing about the address book moves because of it.
                PhoneMirror.alumnusCheckedIn(
                    contact,
                    line: away == AlumniTuning.quarterDays
                        ? "Three months out and I still open the standup doc "
                            + "on a Monday. How's it going over there?"
                        : "Been a while. Still at it?",
                    state: &state
                )
                // MARK: end L1
            }
            if away >= AlumniTuning.foundingDays,
               contact.companyValuation == 0,
               isFounderMaterial(contact) {
                let range = AlumniTuning.foundingValuationRange
                state.networking.contacts[index].companyName = companyName(for: contact)
                state.networking.contacts[index].companyValuation = min(
                    range.upperBound,
                    max(range.lowerBound,
                        Int(contact.skills.total) * AlumniTuning.foundingValuationPerSkillPoint)
                )
                // MARK: Iteration 9 — L1 (phone)
                PhoneMirror.alumnusCheckedIn(
                    contact,
                    line: "Didn't want you to hear it from somebody else: "
                        + "I started \(state.networking.contacts[index].companyName ?? "something"). "
                        + "Two of us and a laptop, so far.",
                    state: &state
                )
                // MARK: end L1
            }
        }
    }

    private static func grown(_ skills: SkillSet, role: EmployeeRole?) -> SkillSet {
        var grown = skills
        let points = AlumniTuning.skillPointsPerQuarter
        switch role?.primarySkill {
        case .coding: grown.coding = min(100, grown.coding + points)
        case .design: grown.design = min(100, grown.design + points)
        case .marketing: grown.marketing = min(100, grown.marketing + points)
        case nil:
            // Operators, lawyers and HR get a little better at everything.
            grown.coding = min(100, grown.coding + points / 3)
            grown.design = min(100, grown.design + points / 3)
            grown.marketing = min(100, grown.marketing + points / 3)
        }
        return grown
    }

    /// Traits derive from the appearance seed, the same way they did on
    /// payroll, so nothing has to be stored to know who is founder
    /// material.
    static func isFounderMaterial(_ contact: Contact) -> Bool {
        !AlumniTuning.founderTraits.isDisjoint(
            with: TraitEffects.derivedTraitIDs(appearanceSeed: contact.appearanceSeed)
        )
    }

    /// "Reyes Labs": the surname and a suffix picked by the seed. No draw.
    private static func companyName(for contact: Contact) -> String {
        let surname = contact.name.split(separator: " ").last.map(String.init) ?? contact.name
        let suffixes = AlumniTuning.companySuffixes
        let suffix = suffixes[Int(contact.appearanceSeed % UInt64(suffixes.count))]
        return "\(surname) \(suffix)"
    }
}
