/// The `"progression"` block of `Balance.json` — founder archetype skill
/// spreads, chapter gating, and the strength of the permanent perks goals
/// hand out.
///
/// Every field decodes with a default, so a balance file that predates the
/// block (or that only lists some of it) still loads. WS-F owns this file
/// and the `"progression"` object; no other workstream edits either.
extension BalanceConfig {
    public struct ProgressionBalance: Codable, Equatable, Sendable {
        /// One founder archetype's starting skills.
        public struct ArchetypeSkills: Codable, Equatable, Sendable {
            public var coding: Double
            public var design: Double
            public var marketing: Double

            public init(coding: Double, design: Double, marketing: Double) {
                self.coding = coding
                self.design = design
                self.marketing = marketing
            }

            var skillSet: SkillSet {
                SkillSet(coding: coding, design: design, marketing: marketing)
            }
        }

        /// Starting skills per `FounderArchetype` raw value. A missing
        /// archetype falls back to the balance's flat founder skills, which
        /// is exactly the pre-archetype founder — which is why `.default`
        /// deliberately ships an *empty* table: a hand-built balance (the
        /// test harness, a migration) keeps today's founder, and only the
        /// shipped `Balance.json`, which lists all three, gives the
        /// archetypes their spreads.
        public var archetypes: [String: ArchetypeSkills]
        /// How many of a chapter's goals must be finished before the next
        /// chapter opens. Below the goal count, so one awkward goal can
        /// never wall the run off.
        public var goalsToAdvanceChapter: Int
        /// Reputation granted per point of a goal's `reputation` reward.
        public var rewardReputationScale: Double
        /// Cash granted per dollar of a goal's `cash` reward.
        public var rewardCashScale: Double
        /// Extra hype per campaign once `pressContacts` is earned.
        public var pressContactsHypeBonus: Double
        /// Extra morale target for every employee once `veteranCrew` is
        /// earned.
        public var veteranCrewMoraleBonus: Double
        /// Extra candidate skill ceiling once `talentMagnet` is earned.
        public var talentMagnetSkillBonus: Double
        /// How many weeks earlier investors start looking once
        /// `investorRolodex` is earned.
        public var investorRolodexWeeksEarlier: Int

        public init(
            archetypes: [String: ArchetypeSkills] = [:],
            goalsToAdvanceChapter: Int = 4,
            rewardReputationScale: Double = 1,
            rewardCashScale: Double = 1,
            pressContactsHypeBonus: Double = 5,
            veteranCrewMoraleBonus: Double = 4,
            talentMagnetSkillBonus: Double = 6,
            investorRolodexWeeksEarlier: Int = 4
        ) {
            self.archetypes = archetypes
            self.goalsToAdvanceChapter = goalsToAdvanceChapter
            self.rewardReputationScale = rewardReputationScale
            self.rewardCashScale = rewardCashScale
            self.pressContactsHypeBonus = pressContactsHypeBonus
            self.veteranCrewMoraleBonus = veteranCrewMoraleBonus
            self.talentMagnetSkillBonus = talentMagnetSkillBonus
            self.investorRolodexWeeksEarlier = investorRolodexWeeksEarlier
        }

        /// What the shipped `Balance.json` carries: hacker 55/25/20,
        /// designer 25/55/20, hustler 25/20/55 — each a 100-point budget
        /// against the pre-archetype founder's flat 40/30/20 (90), a
        /// deliberate, documented +10 for anyone who picks an identity.
        /// (The plan wrote the hustler 30/25/55; that is 110, which would
        /// have made one archetype strictly the strongest, so the spread
        /// keeps the shape and the budget instead.)
        public static let standardArchetypes: [String: ArchetypeSkills] = [
            FounderArchetype.hacker.rawValue:
                ArchetypeSkills(coding: 55, design: 25, marketing: 20),
            FounderArchetype.designer.rawValue:
                ArchetypeSkills(coding: 25, design: 55, marketing: 20),
            FounderArchetype.hustler.rawValue:
                ArchetypeSkills(coding: 25, design: 20, marketing: 55),
        ]

        public static let `default` = ProgressionBalance()

        /// The starting skills for an archetype, falling back to the
        /// balance's flat founder skills when the table has no entry.
        func founderSkills(
            for archetype: FounderArchetype,
            fallback: SkillSet
        ) -> SkillSet {
            archetypes[archetype.rawValue]?.skillSet ?? fallback
        }
    }
}

// MARK: - Codable

// Hand-written so a `"progression"` object that lists only some of the
// tunables still decodes: every key reads with `decodeIfPresent`.

extension BalanceConfig.ProgressionBalance {
    private enum CodingKeys: String, CodingKey {
        case archetypes, goalsToAdvanceChapter, rewardReputationScale, rewardCashScale
        case pressContactsHypeBonus, veteranCrewMoraleBonus, talentMagnetSkillBonus
        case investorRolodexWeeksEarlier
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            archetypes: try container.decodeIfPresent([String: ArchetypeSkills].self, forKey: .archetypes)
                ?? [:],
            goalsToAdvanceChapter: try container.decodeIfPresent(Int.self, forKey: .goalsToAdvanceChapter) ?? 4,
            rewardReputationScale: try container.decodeIfPresent(Double.self, forKey: .rewardReputationScale) ?? 1,
            rewardCashScale: try container.decodeIfPresent(Double.self, forKey: .rewardCashScale) ?? 1,
            pressContactsHypeBonus: try container.decodeIfPresent(Double.self, forKey: .pressContactsHypeBonus) ?? 5,
            veteranCrewMoraleBonus: try container.decodeIfPresent(Double.self, forKey: .veteranCrewMoraleBonus) ?? 4,
            talentMagnetSkillBonus: try container.decodeIfPresent(Double.self, forKey: .talentMagnetSkillBonus) ?? 6,
            investorRolodexWeeksEarlier: try container.decodeIfPresent(
                Int.self, forKey: .investorRolodexWeeksEarlier
            ) ?? 4
        )
    }
}

// Lets `BalanceConfig`'s synthesized decoder read a balance file that has
// no `"progression"` object at all: the concrete overload wins over the generic
// `decode(_:forKey:)`, turning the required key into
// `decodeIfPresent ?? .default`.
extension KeyedDecodingContainer {
    func decode(
        _ type: BalanceConfig.ProgressionBalance.Type,
        forKey key: Key
    ) throws -> BalanceConfig.ProgressionBalance {
        try decodeIfPresent(type, forKey: key) ?? .default
    }
}
