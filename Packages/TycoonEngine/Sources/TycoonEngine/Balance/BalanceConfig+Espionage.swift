import Foundation

// Iteration 11, wave two — W3. What it costs to have something done to a
// rival, how likely it is to work, and how likely it is to come back.
//
// Every number here is read from behind a button on a rival's page or from
// behind `OfficeSecretsState.watching`, so a run that never presses one is
// bit-for-bit the run it was before this file existed, whatever the values
// say. The tuning argument: an operation should be worth roughly a
// quarter's advantage and cost roughly a quarter's caution — half of them
// land, one in five comes back, and the one that comes back is a hearing.

extension BalanceConfig {

    // MARK: - Espionage

    public struct EspionageBalance: Codable, Equatable, Sendable {
        // The five prices. A PI and a poach are the founder's own money;
        // the mole, the roadmap and the hack are invoiced to the company
        // as something they are not.
        public var tailFee: Int
        public var moleFee: Int
        public var poachFee: Int
        public var roadmapFee: Int
        public var hackFee: Int

        // What each is worth to N1's needle.
        public var tailNotoriety: Double
        public var moleNotoriety: Double
        public var poachNotoriety: Double
        public var roadmapNotoriety: Double
        public var hackNotoriety: Double

        // The odds each lands, before nerve, their size and the dossier.
        public var tailSuccess: Double
        public var moleSuccess: Double
        public var poachSuccess: Double
        public var roadmapSuccess: Double
        public var hackSuccess: Double

        // The odds each is traced on the day, before notoriety and Legal.
        public var tailTrace: Double
        public var moleTrace: Double
        public var poachTrace: Double
        public var roadmapTrace: Double
        public var hackTrace: Double

        /// The founder's own attribute, divided down into the odds.
        public var successSkillDivisor: Double
        /// How much a big studio resists everything, at strength 100.
        public var strengthResistance: Double
        /// What a full dossier adds to every other operation's odds.
        public var dossierSuccessBonus: Double
        /// After this many days a dossier is worth half of what it was.
        public var dossierColdDays: Int
        public var successFloor: Double
        public var successCeiling: Double
        /// A botched operation is this much easier to trace.
        public var botchedTraceFactor: Double
        public var traceCeiling: Double
        /// Days between operations, whoever they are against.
        public var cooldownDays: Int
        /// The grudge an operation nobody traced still earns.
        public var quietGrudge: Double

        // What the payoffs are worth.
        /// The dossier's leverage when the investigator does their job.
        public var dossierLeverage: Double
        /// How far out the mole's report is: their launch, this many days
        /// ahead of it.
        public var intelLeadDays: Int
        /// What being ready for their launch takes off it, in quality
        /// points, when you have something of your own on the same topic.
        public var interceptQualityPenalty: Double
        /// Hype the bought roadmap puts on your own build.
        public var roadmapHype: Double
        /// Strength the studio loses when their plan walks out.
        public var roadmapStrengthHit: Double
        /// The fraction of a hacked storefront's weekly units that stop.
        public var hackUnitsFraction: Double
        /// And the reputation it costs them.
        public var hackReputationHit: Double
        /// Strength a studio loses when their best engineer is taken.
        public var poachStrengthHit: Double

        // The other half: what they run against you, and what a sweep of
        // your own office costs.
        /// A rival needs this much grudge before they start one.
        public var rivalGrudgeToAct: Double
        /// A sweep of the office, out of the company's cash.
        public var sweepCost: Int
        /// Grudge a sweep takes off the studio that was running it.
        public var sweepGrudgeRelief: Double
        /// Strength a studio loses when it launches on your false plans.
        public var falsePlansStrengthHit: Double
        /// Reputation a rival's finished operation costs you.
        public var rivalOperationReputationHit: Double

        public init(
            tailFee: Int = 3000,
            moleFee: Int = 9000,
            poachFee: Int = 5000,
            roadmapFee: Int = 16000,
            hackFee: Int = 12000,
            tailNotoriety: Double = 6,
            moleNotoriety: Double = 10,
            poachNotoriety: Double = 12,
            roadmapNotoriety: Double = 14,
            hackNotoriety: Double = 20,
            tailSuccess: Double = 0.72,
            moleSuccess: Double = 0.58,
            poachSuccess: Double = 0.55,
            roadmapSuccess: Double = 0.5,
            hackSuccess: Double = 0.46,
            tailTrace: Double = 0.1,
            moleTrace: Double = 0.16,
            poachTrace: Double = 0.2,
            roadmapTrace: Double = 0.24,
            hackTrace: Double = 0.32,
            successSkillDivisor: Double = 260,
            strengthResistance: Double = 0.28,
            dossierSuccessBonus: Double = 0.22,
            dossierColdDays: Int = 120,
            successFloor: Double = 0.12,
            successCeiling: Double = 0.9,
            botchedTraceFactor: Double = 1.8,
            traceCeiling: Double = 0.7,
            cooldownDays: Int = 21,
            quietGrudge: Double = 18,
            dossierLeverage: Double = 1,
            intelLeadDays: Int = 28,
            interceptQualityPenalty: Double = 12,
            roadmapHype: Double = 22,
            roadmapStrengthHit: Double = 6,
            hackUnitsFraction: Double = 0.55,
            hackReputationHit: Double = 7,
            poachStrengthHit: Double = 5,
            rivalGrudgeToAct: Double = 45,
            sweepCost: Int = 3500,
            sweepGrudgeRelief: Double = 20,
            falsePlansStrengthHit: Double = 9,
            rivalOperationReputationHit: Double = 5
        ) {
            self.tailFee = tailFee
            self.moleFee = moleFee
            self.poachFee = poachFee
            self.roadmapFee = roadmapFee
            self.hackFee = hackFee
            self.tailNotoriety = tailNotoriety
            self.moleNotoriety = moleNotoriety
            self.poachNotoriety = poachNotoriety
            self.roadmapNotoriety = roadmapNotoriety
            self.hackNotoriety = hackNotoriety
            self.tailSuccess = tailSuccess
            self.moleSuccess = moleSuccess
            self.poachSuccess = poachSuccess
            self.roadmapSuccess = roadmapSuccess
            self.hackSuccess = hackSuccess
            self.tailTrace = tailTrace
            self.moleTrace = moleTrace
            self.poachTrace = poachTrace
            self.roadmapTrace = roadmapTrace
            self.hackTrace = hackTrace
            self.successSkillDivisor = successSkillDivisor
            self.strengthResistance = strengthResistance
            self.dossierSuccessBonus = dossierSuccessBonus
            self.dossierColdDays = dossierColdDays
            self.successFloor = successFloor
            self.successCeiling = successCeiling
            self.botchedTraceFactor = botchedTraceFactor
            self.traceCeiling = traceCeiling
            self.cooldownDays = cooldownDays
            self.quietGrudge = quietGrudge
            self.dossierLeverage = dossierLeverage
            self.intelLeadDays = intelLeadDays
            self.interceptQualityPenalty = interceptQualityPenalty
            self.roadmapHype = roadmapHype
            self.roadmapStrengthHit = roadmapStrengthHit
            self.hackUnitsFraction = hackUnitsFraction
            self.hackReputationHit = hackReputationHit
            self.poachStrengthHit = poachStrengthHit
            self.rivalGrudgeToAct = rivalGrudgeToAct
            self.sweepCost = sweepCost
            self.sweepGrudgeRelief = sweepGrudgeRelief
            self.falsePlansStrengthHit = falsePlansStrengthHit
            self.rivalOperationReputationHit = rivalOperationReputationHit
        }

        /// The shipped numbers. Like `officeSecrets`, the default is not
        /// "switched off" — there is nothing to switch off until the
        /// founder presses a button — so a balance file with no
        /// `"espionage"` object still gets the game that ships.
        public static let `default` = EspionageBalance()

        // Decode-if-present on every field, so a balance file written
        // before this block existed reads exactly the shipped numbers.
        private enum CodingKeys: String, CodingKey {
            case tailFee, moleFee, poachFee, roadmapFee, hackFee
            case tailNotoriety, moleNotoriety, poachNotoriety, roadmapNotoriety, hackNotoriety
            case tailSuccess, moleSuccess, poachSuccess, roadmapSuccess, hackSuccess
            case tailTrace, moleTrace, poachTrace, roadmapTrace, hackTrace
            case successSkillDivisor, strengthResistance, dossierSuccessBonus, dossierColdDays
            case successFloor, successCeiling, botchedTraceFactor, traceCeiling
            case cooldownDays, quietGrudge
            case dossierLeverage, intelLeadDays, interceptQualityPenalty
            case roadmapHype, roadmapStrengthHit, hackUnitsFraction, hackReputationHit
            case poachStrengthHit
            case rivalGrudgeToAct, sweepCost, sweepGrudgeRelief, falsePlansStrengthHit
            case rivalOperationReputationHit
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let fallback = EspionageBalance()
            func int(_ key: CodingKeys, _ value: Int) throws -> Int {
                try container.decodeIfPresent(Int.self, forKey: key) ?? value
            }
            func double(_ key: CodingKeys, _ value: Double) throws -> Double {
                try container.decodeIfPresent(Double.self, forKey: key) ?? value
            }
            self.init(
                tailFee: try int(.tailFee, fallback.tailFee),
                moleFee: try int(.moleFee, fallback.moleFee),
                poachFee: try int(.poachFee, fallback.poachFee),
                roadmapFee: try int(.roadmapFee, fallback.roadmapFee),
                hackFee: try int(.hackFee, fallback.hackFee),
                tailNotoriety: try double(.tailNotoriety, fallback.tailNotoriety),
                moleNotoriety: try double(.moleNotoriety, fallback.moleNotoriety),
                poachNotoriety: try double(.poachNotoriety, fallback.poachNotoriety),
                roadmapNotoriety: try double(.roadmapNotoriety, fallback.roadmapNotoriety),
                hackNotoriety: try double(.hackNotoriety, fallback.hackNotoriety),
                tailSuccess: try double(.tailSuccess, fallback.tailSuccess),
                moleSuccess: try double(.moleSuccess, fallback.moleSuccess),
                poachSuccess: try double(.poachSuccess, fallback.poachSuccess),
                roadmapSuccess: try double(.roadmapSuccess, fallback.roadmapSuccess),
                hackSuccess: try double(.hackSuccess, fallback.hackSuccess),
                tailTrace: try double(.tailTrace, fallback.tailTrace),
                moleTrace: try double(.moleTrace, fallback.moleTrace),
                poachTrace: try double(.poachTrace, fallback.poachTrace),
                roadmapTrace: try double(.roadmapTrace, fallback.roadmapTrace),
                hackTrace: try double(.hackTrace, fallback.hackTrace),
                successSkillDivisor: try double(.successSkillDivisor, fallback.successSkillDivisor),
                strengthResistance: try double(.strengthResistance, fallback.strengthResistance),
                dossierSuccessBonus: try double(.dossierSuccessBonus, fallback.dossierSuccessBonus),
                dossierColdDays: try int(.dossierColdDays, fallback.dossierColdDays),
                successFloor: try double(.successFloor, fallback.successFloor),
                successCeiling: try double(.successCeiling, fallback.successCeiling),
                botchedTraceFactor: try double(.botchedTraceFactor, fallback.botchedTraceFactor),
                traceCeiling: try double(.traceCeiling, fallback.traceCeiling),
                cooldownDays: try int(.cooldownDays, fallback.cooldownDays),
                quietGrudge: try double(.quietGrudge, fallback.quietGrudge),
                dossierLeverage: try double(.dossierLeverage, fallback.dossierLeverage),
                intelLeadDays: try int(.intelLeadDays, fallback.intelLeadDays),
                interceptQualityPenalty: try double(
                    .interceptQualityPenalty, fallback.interceptQualityPenalty
                ),
                roadmapHype: try double(.roadmapHype, fallback.roadmapHype),
                roadmapStrengthHit: try double(.roadmapStrengthHit, fallback.roadmapStrengthHit),
                hackUnitsFraction: try double(.hackUnitsFraction, fallback.hackUnitsFraction),
                hackReputationHit: try double(.hackReputationHit, fallback.hackReputationHit),
                poachStrengthHit: try double(.poachStrengthHit, fallback.poachStrengthHit),
                rivalGrudgeToAct: try double(.rivalGrudgeToAct, fallback.rivalGrudgeToAct),
                sweepCost: try int(.sweepCost, fallback.sweepCost),
                sweepGrudgeRelief: try double(.sweepGrudgeRelief, fallback.sweepGrudgeRelief),
                falsePlansStrengthHit: try double(
                    .falsePlansStrengthHit, fallback.falsePlansStrengthHit
                ),
                rivalOperationReputationHit: try double(
                    .rivalOperationReputationHit, fallback.rivalOperationReputationHit
                )
            )
        }
    }
}
