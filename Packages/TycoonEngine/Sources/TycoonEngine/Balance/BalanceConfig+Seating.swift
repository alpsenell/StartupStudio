import Foundation

// MARK: S1 (seating)

// Iteration 16 — S1. Who sits next to whom
// (docs/product/iteration-15-pm/meta.md §3, A3 Seating).
//
// Every number here is read only once the player has put somebody at a
// desk (`Company.seating` non-empty). A run that never seats anyone — every
// bot, every fixture — never reads this block, so it moves no pacing gate.
// `"seating"` is appended at the end of `Balance.json`; a balance file
// without it reads these defaults.
//
// - A mentor beside somebody weaker in the mentor's best skill teaches
//   them every week: `relationships.mentorSkillGain × mentorGainScale ×
//   gap / 100` points, never past the mentor's own level, and gives up
//   `mentorOutputCost` of their own output every day they do.
// - A grumbler's two neighbours lose `grumblerMoraleDelta` morale a day,
//   on top of what the grumbler already does to the whole room.
// - Two people beside each other with a bond of 60 or more gain
//   `friendBondGain` of it a week — and it is where the office's romance
//   and clique threads start.
// - Whoever sits behind the founder's desk gains `founderBondGain` of
//   founder bond a week.
// - Whoever sits by the door is `doorPoachWeight` points further up a
//   recruiter's list.

extension BalanceConfig {

    // MARK: - Seating

    public struct SeatingBalance: Codable, Equatable, Sendable {
        /// Share of a mentor's own daily output given up on any day they
        /// have somebody weaker beside them.
        public var mentorOutputCost: Double
        /// Scales the weekly lesson: `mentorSkillGain × this × gap / 100`.
        public var mentorGainScale: Double
        /// Morale a day for each neighbour of a grumbler (negative).
        public var grumblerMoraleDelta: Double
        /// Bond a week for two neighbours already at 60 or more.
        public var friendBondGain: Double
        /// Founder bond a week for whoever sits behind the founder's desk.
        public var founderBondGain: Double
        /// Poach-list score for whoever sits at the desk by the door, on
        /// the scale of `rivals.poachSkillWeight × skills.total`.
        public var doorPoachWeight: Double

        public init(
            mentorOutputCost: Double = 0.1,
            mentorGainScale: Double = 1,
            grumblerMoraleDelta: Double = -0.1,
            friendBondGain: Double = 2,
            founderBondGain: Double = 2,
            doorPoachWeight: Double = 60
        ) {
            self.mentorOutputCost = mentorOutputCost
            self.mentorGainScale = mentorGainScale
            self.grumblerMoraleDelta = grumblerMoraleDelta
            self.friendBondGain = friendBondGain
            self.founderBondGain = founderBondGain
            self.doorPoachWeight = doorPoachWeight
        }

        public static let `default` = SeatingBalance()

        private enum CodingKeys: String, CodingKey {
            case mentorOutputCost, mentorGainScale, grumblerMoraleDelta
            case friendBondGain, founderBondGain, doorPoachWeight
        }

        /// Every key optional, falling back to the default.
        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let d = SeatingBalance.default
            self.init(
                mentorOutputCost: try c.decodeIfPresent(Double.self, forKey: .mentorOutputCost)
                    ?? d.mentorOutputCost,
                mentorGainScale: try c.decodeIfPresent(Double.self, forKey: .mentorGainScale)
                    ?? d.mentorGainScale,
                grumblerMoraleDelta: try c.decodeIfPresent(Double.self, forKey: .grumblerMoraleDelta)
                    ?? d.grumblerMoraleDelta,
                friendBondGain: try c.decodeIfPresent(Double.self, forKey: .friendBondGain)
                    ?? d.friendBondGain,
                founderBondGain: try c.decodeIfPresent(Double.self, forKey: .founderBondGain)
                    ?? d.founderBondGain,
                doorPoachWeight: try c.decodeIfPresent(Double.self, forKey: .doorPoachWeight)
                    ?? d.doorPoachWeight
            )
        }
    }
}

// Lets `BalanceConfig`'s synthesized decoder read a balance file with no
// `"seating"` object.
extension KeyedDecodingContainer {
    func decode(
        _ type: BalanceConfig.SeatingBalance.Type,
        forKey key: Key
    ) throws -> BalanceConfig.SeatingBalance {
        try decodeIfPresent(type, forKey: key) ?? .default
    }
}

// MARK: end S1
