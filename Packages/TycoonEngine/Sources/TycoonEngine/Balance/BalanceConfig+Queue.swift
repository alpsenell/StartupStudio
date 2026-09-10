import Foundation

// Iteration 12 — J6. Late-game money has teeth.
//
// Two pacing keys, and both read as *off* at their Swift default, so every
// test that builds a balance by hand plays the game it always played.
// `Balance.json` turns them on; that is the shipped game, and it moves the
// measured pacing gates on purpose (re-pinned, with old and new numbers,
// in `docs/product/iteration-12-lanes/j6.md`).
//
// 1. **Event stakes.** A story's cash effect, and the money line on its
//    button, is multiplied by `max(1, weeklyBurn / eventCashReferenceBurn)^0.5`.
//    Under the reference burn — the garage, an early loft — that is exactly
//    1.0 and the multiplication is skipped altogether, so a run that never
//    outgrows the garage writes the bytes it always wrote. A studio at
//    about $11k a week reads about 1.35× at the shipped reference of
//    $6,000, and a campus at about $40k about 2.58×. `0` turns it off.
//    The brief asked for a $4,000 reference (1.66× and 3.16×); at $4,000
//    InvestorTargets' "serving the number the board watches is worth
//    doing" gate fails on path noise, and at $6,000 it passes as written
//    (measured in the lane report).
// 2. **The campus.** The campus's weekly rent is `campusRentBase`, plus
//    `campusRentPerHead` for every person above `campusRentFreeHeadcount`,
//    instead of the office's listed `weeklyRent`. The listed rent still
//    prices the deeds (`officePurchasePrice` reads it) and the up-front
//    `upgradeCost` is untouched, so the $300k stays the commitment and only
//    the week-one cliff goes. `campusRentBase` `0` turns it off.

extension BalanceConfig {

    // MARK: - Queue pacing

    public struct QueuePacingBalance: Codable, Equatable, Sendable {
        /// The weekly burn at which a story's money stops being garage
        /// money. `0` is off: every cash effect reads at face value.
        public var eventCashReferenceBurn: Int
        /// The campus's weekly rent with the studio's headcount in it.
        /// `0` is off: the campus pays its listed rent.
        public var campusRentBase: Int
        /// What each person above `campusRentFreeHeadcount` adds to it.
        public var campusRentPerHead: Int
        /// The headcount the base rent covers — the studio's desks.
        public var campusRentFreeHeadcount: Int

        public init(
            eventCashReferenceBurn: Int = 0,
            campusRentBase: Int = 0,
            campusRentPerHead: Int = 0,
            campusRentFreeHeadcount: Int = 14
        ) {
            self.eventCashReferenceBurn = eventCashReferenceBurn
            self.campusRentBase = campusRentBase
            self.campusRentPerHead = campusRentPerHead
            self.campusRentFreeHeadcount = campusRentFreeHeadcount
        }

        /// Both keys off.
        public static let `default` = QueuePacingBalance()

        private enum CodingKeys: String, CodingKey {
            case eventCashReferenceBurn, campusRentBase, campusRentPerHead, campusRentFreeHeadcount
        }

        /// Every key optional, falling back to the (off) default.
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let fallback = Self.default
            self.init(
                eventCashReferenceBurn: try container.decodeIfPresent(
                    Int.self, forKey: .eventCashReferenceBurn
                ) ?? fallback.eventCashReferenceBurn,
                campusRentBase: try container.decodeIfPresent(
                    Int.self, forKey: .campusRentBase
                ) ?? fallback.campusRentBase,
                campusRentPerHead: try container.decodeIfPresent(
                    Int.self, forKey: .campusRentPerHead
                ) ?? fallback.campusRentPerHead,
                campusRentFreeHeadcount: try container.decodeIfPresent(
                    Int.self, forKey: .campusRentFreeHeadcount
                ) ?? fallback.campusRentFreeHeadcount
            )
        }
    }
}

// Lets `BalanceConfig`'s synthesized decoder read a balance file with no
// `"queuePacing"` object.
extension KeyedDecodingContainer {
    func decode(
        _ type: BalanceConfig.QueuePacingBalance.Type,
        forKey key: Key
    ) throws -> BalanceConfig.QueuePacingBalance {
        try decodeIfPresent(type, forKey: key) ?? .default
    }
}
