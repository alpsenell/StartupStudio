import Foundation

// Iteration 11 — N4. Fame: what a post reaches, what reach is worth, and
// what fame buys at each of its five steps.
//
// Every knob here is read only once `state.fame != .empty`, which happens
// on the first tap of *Post* and never happens on its own. A run that
// never opens the feed reads none of these numbers whatever they say, so
// the balance argument is entirely about how the feed feels once it is
// open — not about the shipped pacing, which cannot move.
//
// The shape of the curve: a post reaches four hundred people at zero
// followers, five thousand at ten thousand followers, and never more than
// twenty-five thousand of them from the follower count alone, because the
// audience saturates (`Fame.reach` explains why at length: a linear one
// compounds into tens of millions over a long run). Two per cent of reach
// becomes followers. Fame is the square root of followers plus a fortnight
// of reach, approached slowly and leaking half a point a week. So the
// first hundred followers take a fortnight of daily posting, the first
// thousand take a season, the tens of thousands take years, and stopping
// for a month costs a level.

extension BalanceConfig {

    // MARK: - Fame and the feed

    public struct FameBalance: Codable, Equatable, Sendable {

        // MARK: Reach

        /// The people a post reaches with no followers at all: the
        /// algorithm's charity. Small enough that the first week is quiet.
        public var reachBase: Double
        /// Extra audience per follower *at the start*: the slope of the
        /// saturating curve at zero followers. Under one, because a
        /// follower is not a reader.
        public var reachPerFollower: Double
        /// The most audience followers can ever add, however many there
        /// are. The asymptote that stops the feed compounding into tens of
        /// millions over a long run — see `Fame.reach`.
        public var reachAudienceCeiling: Double
        /// How much fame stretches reach: reach × (1 + fame/100 × span).
        /// At fame 100 a post reaches four times what it would at zero.
        public var reachFameSpan: Double
        /// The uniform roll's floor and ceiling. The spread is the point:
        /// the same post twice is not the same post.
        public var rollFloor: Double
        public var rollCeiling: Double
        /// A roll at or above this went long.
        public var viralRoll: Double
        /// What going long multiplies the reach by.
        public var viralMultiplier: Double
        /// The multiplier on a day the industry news is loud.
        public var newsDayMultiplier: Double
        /// How recent an industry-news beat has to be to count as loud.
        public var newsDayWindow: Int

        // MARK: The kinds

        /// Reach multiplier per `FamePostKind`, keyed by raw value. A kind
        /// missing from the map reads 1.
        public var kindReach: [String: Double]

        // MARK: Followers and fame

        /// Followers per unit of reach. Two per cent: a thousand-reach
        /// post is twenty new people.
        public var followersPerReach: Double
        /// `sqrt(followers) × this` is the follower half of fame. At 0.55,
        /// ten thousand followers reads 55.
        public var famePerRootFollower: Double
        /// The follower half cannot exceed this on its own.
        public var followerScoreCap: Double
        /// Reach in the trailing window per point of the reach half.
        public var reachPerFamePoint: Double
        /// The reach half cannot exceed this on its own.
        public var reachScoreCap: Double
        /// Days of posts the reach half looks back over.
        public var recentReachWindow: Int
        /// How much of the gap to the target fame closes each day.
        public var approach: Double
        /// Fame lost each day regardless. Silence is expensive.
        public var dailyDecay: Double

        // MARK: The five steps

        public var knownAt: Double
        public var followedAt: Double
        public var notableAt: Double
        public var famousAt: Double
        public var starAt: Double

        // MARK: What fame buys

        /// Hype added to every build in development each day, per point of
        /// fame. Zero fame, zero hype — the identity `MarketingSystem`
        /// needs.
        public var hypePerFamePointDaily: Double
        /// Fame above `followedAt` per extra unasked-for applicant.
        public var famePerExtraApplicant: Double
        /// The most applicants fame can put in the pool in one week.
        public var inboundApplicantsMax: Int
        /// The pool never grows past this many people through fame alone.
        public var inboundPoolCap: Int
        /// Warmth a journalist opens with, per point of fame.
        public var journalistWarmthPerFamePoint: Double
        /// …capped here, well inside the pitch room's ±100, so fame is a
        /// head start and never the whole conversation.
        public var journalistWarmthCap: Double

        // MARK: The beef

        /// Followers a round of a beef brings in, per round.
        public var beefFollowersPerRound: Int
        /// Reputation a beef costs the company per round escalated.
        public var beefReputationPerRound: Double
        /// Mood the founder loses each round they escalate.
        public var beefMoodPerRound: Double
        /// Days of silence after which a beef simply ends.
        public var beefFadeDays: Int
        /// The most rounds a beef can go before the world stops caring.
        public var beefMaxRounds: Int

        // MARK: The cancellation

        /// Weekly chance an old post surfaces, at `notableAt` exactly.
        public var cancelWeeklyChance: Double
        /// …scaled by fame above that: chance × (1 + over/100 × span).
        public var cancelFameSpan: Double
        /// Posts the founder must have on the record before anything can
        /// be dug out of it.
        public var cancelMinPosts: Int
        /// Weeks after a cancellation before another can be raised.
        public var cancelCooldownWeeks: Int
        /// Fraction of followers each answer costs.
        public var cancelApologiseFollowerLoss: Double
        public var cancelDoubleDownFollowerLoss: Double
        public var cancelDeleteFollowerLoss: Double
        /// Fame each answer costs outright.
        public var cancelApologiseFameLoss: Double
        public var cancelDoubleDownFameLoss: Double
        public var cancelDeleteFameLoss: Double
        /// Company reputation each answer costs.
        public var cancelApologiseReputation: Double
        public var cancelDoubleDownReputation: Double
        public var cancelDeleteReputation: Double
        /// Founder mood each answer costs.
        public var cancelApologiseMood: Double
        public var cancelDoubleDownMood: Double
        public var cancelDeleteMood: Double

        public init(
            reachBase: Double = 420,
            reachPerFollower: Double = 0.6,
            reachAudienceCeiling: Double = 25_000,
            reachFameSpan: Double = 3,
            rollFloor: Double = 0.45,
            rollCeiling: Double = 2,
            viralRoll: Double = 1.85,
            viralMultiplier: Double = 5,
            newsDayMultiplier: Double = 1.3,
            newsDayWindow: Int = 3,
            kindReach: [String: Double] = [
                "take": 1, "launch": 1.35, "photo": 0.75, "subtweet": 1.7, "reply": 1.1,
            ],
            followersPerReach: Double = 0.02,
            famePerRootFollower: Double = 0.55,
            followerScoreCap: Double = 75,
            reachPerFamePoint: Double = 3_500,
            reachScoreCap: Double = 25,
            recentReachWindow: Int = 14,
            approach: Double = 0.12,
            dailyDecay: Double = 0.07,
            knownAt: Double = 8,
            followedAt: Double = 20,
            notableAt: Double = 38,
            famousAt: Double = 58,
            starAt: Double = 78,
            hypePerFamePointDaily: Double = 0.05,
            famePerExtraApplicant: Double = 18,
            inboundApplicantsMax: Int = 3,
            inboundPoolCap: Int = 12,
            journalistWarmthPerFamePoint: Double = 0.45,
            journalistWarmthCap: Double = 40,
            beefFollowersPerRound: Int = 260,
            beefReputationPerRound: Double = 1.2,
            beefMoodPerRound: Double = 3,
            beefFadeDays: Int = 14,
            beefMaxRounds: Int = 5,
            cancelWeeklyChance: Double = 0.1,
            cancelFameSpan: Double = 1.5,
            cancelMinPosts: Int = 12,
            cancelCooldownWeeks: Int = 12,
            cancelApologiseFollowerLoss: Double = 0.12,
            cancelDoubleDownFollowerLoss: Double = 0.28,
            cancelDeleteFollowerLoss: Double = 0.2,
            cancelApologiseFameLoss: Double = 4,
            cancelDoubleDownFameLoss: Double = 2,
            cancelDeleteFameLoss: Double = 8,
            cancelApologiseReputation: Double = -1,
            cancelDoubleDownReputation: Double = -5,
            cancelDeleteReputation: Double = -3,
            cancelApologiseMood: Double = -6,
            cancelDoubleDownMood: Double = -2,
            cancelDeleteMood: Double = -9
        ) {
            self.reachBase = reachBase
            self.reachPerFollower = reachPerFollower
            self.reachAudienceCeiling = reachAudienceCeiling
            self.reachFameSpan = reachFameSpan
            self.rollFloor = rollFloor
            self.rollCeiling = rollCeiling
            self.viralRoll = viralRoll
            self.viralMultiplier = viralMultiplier
            self.newsDayMultiplier = newsDayMultiplier
            self.newsDayWindow = newsDayWindow
            self.kindReach = kindReach
            self.followersPerReach = followersPerReach
            self.famePerRootFollower = famePerRootFollower
            self.followerScoreCap = followerScoreCap
            self.reachPerFamePoint = reachPerFamePoint
            self.reachScoreCap = reachScoreCap
            self.recentReachWindow = recentReachWindow
            self.approach = approach
            self.dailyDecay = dailyDecay
            self.knownAt = knownAt
            self.followedAt = followedAt
            self.notableAt = notableAt
            self.famousAt = famousAt
            self.starAt = starAt
            self.hypePerFamePointDaily = hypePerFamePointDaily
            self.famePerExtraApplicant = famePerExtraApplicant
            self.inboundApplicantsMax = inboundApplicantsMax
            self.inboundPoolCap = inboundPoolCap
            self.journalistWarmthPerFamePoint = journalistWarmthPerFamePoint
            self.journalistWarmthCap = journalistWarmthCap
            self.beefFollowersPerRound = beefFollowersPerRound
            self.beefReputationPerRound = beefReputationPerRound
            self.beefMoodPerRound = beefMoodPerRound
            self.beefFadeDays = beefFadeDays
            self.beefMaxRounds = beefMaxRounds
            self.cancelWeeklyChance = cancelWeeklyChance
            self.cancelFameSpan = cancelFameSpan
            self.cancelMinPosts = cancelMinPosts
            self.cancelCooldownWeeks = cancelCooldownWeeks
            self.cancelApologiseFollowerLoss = cancelApologiseFollowerLoss
            self.cancelDoubleDownFollowerLoss = cancelDoubleDownFollowerLoss
            self.cancelDeleteFollowerLoss = cancelDeleteFollowerLoss
            self.cancelApologiseFameLoss = cancelApologiseFameLoss
            self.cancelDoubleDownFameLoss = cancelDoubleDownFameLoss
            self.cancelDeleteFameLoss = cancelDeleteFameLoss
            self.cancelApologiseReputation = cancelApologiseReputation
            self.cancelDoubleDownReputation = cancelDoubleDownReputation
            self.cancelDeleteReputation = cancelDeleteReputation
            self.cancelApologiseMood = cancelApologiseMood
            self.cancelDoubleDownMood = cancelDoubleDownMood
            self.cancelDeleteMood = cancelDeleteMood
        }

        /// The shipped feed. Like the bug hunt, the default is not
        /// "switched off" — there is nothing to switch off until the
        /// founder posts — so a balance file with no `"fame"` object still
        /// gets the game that ships.
        public static let `default` = FameBalance()

        /// The reach multiplier for a post kind, 1 for anything the map
        /// does not name.
        public func reachMultiplier(_ kind: FamePostKind) -> Double {
            kindReach[kind.rawValue] ?? 1
        }

        /// What one answer to a cancellation costs: followers as a
        /// fraction, then fame, reputation and mood outright.
        public func cancelCost(
            _ response: FameCancelResponse
        ) -> (followerLoss: Double, fame: Double, reputation: Double, mood: Double) {
            switch response {
            case .apologise:
                (cancelApologiseFollowerLoss, cancelApologiseFameLoss,
                 cancelApologiseReputation, cancelApologiseMood)
            case .doubleDown:
                (cancelDoubleDownFollowerLoss, cancelDoubleDownFameLoss,
                 cancelDoubleDownReputation, cancelDoubleDownMood)
            case .delete:
                (cancelDeleteFollowerLoss, cancelDeleteFameLoss,
                 cancelDeleteReputation, cancelDeleteMood)
            }
        }
    }
}

// Lets `BalanceConfig`'s synthesized decoder read a balance file with no
// `"fame"` object.
extension KeyedDecodingContainer {
    func decode(
        _ type: BalanceConfig.FameBalance.Type,
        forKey key: Key
    ) throws -> BalanceConfig.FameBalance {
        try decodeIfPresent(type, forKey: key) ?? .default
    }
}
