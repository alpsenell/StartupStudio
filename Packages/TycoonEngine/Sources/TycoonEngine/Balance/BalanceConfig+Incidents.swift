import Foundation

// Iteration 10 — M3. The incident room: when a live product breaks, how
// long the room runs, and what an hour of three people's attention is
// worth.
//
// Identity at the default is kept by the *gate*, not by the numbers: every
// value here is read only after `IncidentSystem` has raised an incident,
// and it cannot raise one until `state.economy.incidents.hasOpenedProducts`
// is true — which only the app sets, and only when the player opens the
// Products tab. A pacing bot, a fixture replay and a headless run never
// touch a single knob below.

extension BalanceConfig {

    // MARK: - Incidents

    public struct IncidentBalance: Codable, Equatable, Sendable {

        // MARK: Whether one happens at all

        /// The master switch. Off means no incident is ever raised, whatever
        /// the player has opened.
        public var enabled: Bool
        /// Days before the same product can have another one. A quarter.
        public var cooldownDays: Int
        /// Days after a patch lands that a bad-patch incident can be raised
        /// from it.
        public var badPatchWindowDays: Int
        /// Live bugs, as a multiple of `economy.liveBugAlarmThreshold`, that
        /// a freshly patched product needs before the patch counts as bad.
        public var badPatchBugFactor: Double
        /// How much bigger this week's units have to be than last week's
        /// before the servers are considered to be melting.
        public var spikeGrowthFactor: Double
        /// The share of the week's revenue the hosting bill has to eat
        /// before a spike is an incident rather than a good week.
        public var spikeHostingShare: Double
        /// Minimum weekly units (or subscribers) before either the spike or
        /// the leak is worth a room. Below this nobody would notice.
        public var minimumReach: Int
        /// Chance per week that a leak is rolled, on a product big enough
        /// for one. The only draw in the whole feature, from `socialRNG`,
        /// and only ever taken once the player has opened the Products tab.
        public var leakWeeklyChance: Double
        /// The leak chance, multiplied, when the studio has a Legal
        /// department. Lawyers are the thing that stops this one.
        public var leakLegalFactor: Double

        // MARK: The room

        /// How many hours of work the room has before the day is gone.
        public var hoursPerIncident: Int
        /// Progress one competent person lands on a lane in an hour, before
        /// their skill and role are read.
        public var pointsPerPersonHour: Double
        /// The skill window: someone at skill 0 works at
        /// `skillFloor`, someone at 100 at `skillFloor + skillSpan`.
        public var skillFloor: Double
        public var skillSpan: Double
        /// What the right role is worth on a lane.
        public var roleBonus: Double
        /// The founder counts for this much of a person on any lane: they
        /// know the system, and it is their company on fire.
        public var founderFactor: Double

        // MARK: What it costs

        /// How much of the bleed a fully mitigated incident stops.
        public var mitigateRelief: Double
        /// How much of it good communication stops on its own.
        public var communicateRelief: Double
        /// The most the two together can stop. Some people always leave.
        public var reliefCap: Double
        /// Credibility at zero communication; the rest is earned.
        public var credibilityFloor: Double
        /// Reputation lost for promising a fix that did not ship.
        public var brokenPromisePenalty: Double
        /// Hype (for a one-off product) lost per user who walked. A
        /// non-subscription release has no subscriber count to churn, so the
        /// audience leaving shows up as the word of mouth going with them.
        public var hypePerUserLost: Double

        public init(
            enabled: Bool = true,
            cooldownDays: Int = 91,
            badPatchWindowDays: Int = 3,
            badPatchBugFactor: Double = 1.0,
            spikeGrowthFactor: Double = 1.8,
            spikeHostingShare: Double = 0.35,
            minimumReach: Int = 120,
            leakWeeklyChance: Double = 0.02,
            leakLegalFactor: Double = 0.25,
            hoursPerIncident: Int = 8,
            pointsPerPersonHour: Double = 9.0,
            skillFloor: Double = 0.6,
            skillSpan: Double = 0.9,
            roleBonus: Double = 0.45,
            founderFactor: Double = 1.15,
            mitigateRelief: Double = 0.6,
            communicateRelief: Double = 0.3,
            reliefCap: Double = 0.9,
            credibilityFloor: Double = 0.4,
            brokenPromisePenalty: Double = 6.0,
            hypePerUserLost: Double = 0.02
        ) {
            self.enabled = enabled
            self.cooldownDays = cooldownDays
            self.badPatchWindowDays = badPatchWindowDays
            self.badPatchBugFactor = badPatchBugFactor
            self.spikeGrowthFactor = spikeGrowthFactor
            self.spikeHostingShare = spikeHostingShare
            self.minimumReach = minimumReach
            self.leakWeeklyChance = leakWeeklyChance
            self.leakLegalFactor = leakLegalFactor
            self.hoursPerIncident = hoursPerIncident
            self.pointsPerPersonHour = pointsPerPersonHour
            self.skillFloor = skillFloor
            self.skillSpan = skillSpan
            self.roleBonus = roleBonus
            self.founderFactor = founderFactor
            self.mitigateRelief = mitigateRelief
            self.communicateRelief = communicateRelief
            self.reliefCap = reliefCap
            self.credibilityFloor = credibilityFloor
            self.brokenPromisePenalty = brokenPromisePenalty
            self.hypePerUserLost = hypePerUserLost
        }

        /// The shipped room. Like `sabbatical`, the default is not "off":
        /// there is nothing to switch off until a live product breaks under
        /// a player who has opened the Products tab, and a balance file with
        /// no `"incidents"` object should still be able to run one.
        public static let `default` = IncidentBalance()
    }
}

// Lets `BalanceConfig`'s synthesized decoder read a balance file with no
// `"incidents"` object.
extension KeyedDecodingContainer {
    func decode(
        _ type: BalanceConfig.IncidentBalance.Type,
        forKey key: Key
    ) throws -> BalanceConfig.IncidentBalance {
        try decodeIfPresent(type, forKey: key) ?? .default
    }
}
