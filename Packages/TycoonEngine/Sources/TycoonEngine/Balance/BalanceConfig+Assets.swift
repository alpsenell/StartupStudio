import Foundation

// Iteration 11 — N3. The catalog of everything the founder can own, catch,
// treat or become dependent on: four cars, two properties, three pets,
// three casino games, a lottery ticket, a crypto wallet, five ailments and
// four vices.
//
// Every number here is read only from `AssetsSystem`, and `AssetsSystem`
// returns on its first line while `state.assets` is `.empty` — which it is
// until the player opens the Assets screen. So a balance file with no
// `"assets"` object, and a run that never opens the screen, are both
// exactly the game that shipped, whatever these numbers say.

extension BalanceConfig {

    // MARK: - Assets, vices and the doctor

    public struct AssetsBalance: Codable, Equatable, Sendable {

        // MARK: Things you own

        /// One car, property or pet in the catalog. The same shape for all
        /// three because the founder's relationship to all three is the
        /// same: a price, a weekly bill, a thing that can go wrong, and a
        /// small amount of happiness for as long as it does not.
        public struct AssetDef: Codable, Equatable, Sendable, Identifiable {
            public var id: String
            public var kind: String
            /// What the player sees.
            public var name: String
            /// One deadpan line under the name.
            public var note: String
            public var price: Int
            /// Insurance, fuel, food, the service plan.
            public var weeklyCost: Int
            /// What a tenant pays, when the thing is let out.
            public var weeklyRent: Int
            /// Weekly chance the thing stops working: a gearbox, a burst
            /// pipe, a limp.
            public var faultChance: Double
            /// Weekly chance it is gone: stolen off the drive, or out of
            /// the gate and away.
            public var lossChance: Double
            /// What putting it right costs.
            public var repairCost: Int
            /// Fraction of the price it fetches second-hand.
            public var resaleFraction: Double
            /// Mood a day while it is yours and working.
            public var moodDrift: Double
            /// How much it says about you, for the relationships drift.
            public var prestige: Double

            public init(
                id: String,
                kind: String,
                name: String,
                note: String,
                price: Int,
                weeklyCost: Int,
                weeklyRent: Int = 0,
                faultChance: Double,
                lossChance: Double,
                repairCost: Int,
                resaleFraction: Double,
                moodDrift: Double,
                prestige: Double = 0
            ) {
                self.id = id
                self.kind = kind
                self.name = name
                self.note = note
                self.price = price
                self.weeklyCost = weeklyCost
                self.weeklyRent = weeklyRent
                self.faultChance = faultChance
                self.lossChance = lossChance
                self.repairCost = repairCost
                self.resaleFraction = resaleFraction
                self.moodDrift = moodDrift
                self.prestige = prestige
            }

            public var assetKind: AssetKind { AssetKind(rawValue: kind) ?? .car }
        }

        // MARK: The games

        /// One table at the casino. `winChance × payout` is under 1 in all
        /// three, which is the entire point of a casino.
        public struct AssetGameDef: Codable, Equatable, Sendable, Identifiable {
            public var id: String
            public var name: String
            public var note: String
            public var minStake: Int
            public var maxStake: Int
            public var winChance: Double
            /// What a winning stake comes back as, stake included.
            public var payout: Double
            /// Gambling dependency a hand adds.
            public var viceGain: Double

            public init(
                id: String, name: String, note: String,
                minStake: Int, maxStake: Int,
                winChance: Double, payout: Double, viceGain: Double
            ) {
                self.id = id
                self.name = name
                self.note = note
                self.minStake = minStake
                self.maxStake = maxStake
                self.winChance = winChance
                self.payout = payout
                self.viceGain = viceGain
            }

            /// What a dollar staked comes back as, on average.
            public var expectedReturn: Double { winChance * payout }
        }

        /// The weekly ticket. Three prizes, and an expected return of
        /// about forty cents on the dollar.
        public struct AssetLotteryDef: Codable, Equatable, Sendable {
            public var ticketCost: Int
            public var jackpot: Int
            public var jackpotChance: Double
            public var midPrize: Int
            public var midChance: Double
            public var smallPrize: Int
            public var smallChance: Double
            public var viceGain: Double

            public init(
                ticketCost: Int = 20,
                jackpot: Int = 250_000,
                jackpotChance: Double = 0.00002,
                midPrize: Int = 2000,
                midChance: Double = 0.0012,
                smallPrize: Int = 40,
                smallChance: Double = 0.035,
                viceGain: Double = 1.5
            ) {
                self.ticketCost = ticketCost
                self.jackpot = jackpot
                self.jackpotChance = jackpotChance
                self.midPrize = midPrize
                self.midChance = midChance
                self.smallPrize = smallPrize
                self.smallChance = smallChance
                self.viceGain = viceGain
            }
        }

        /// The wallet. A weekly log-normal step, clamped, with a spread on
        /// both sides of every trade so churning is not free.
        public struct AssetCryptoDef: Codable, Equatable, Sendable {
            public var startingPrice: Double
            public var weeklyDrift: Double
            public var weeklySigma: Double
            public var minPrice: Double
            public var maxPrice: Double
            /// Taken off both buys and sells.
            public var spread: Double

            public init(
                startingPrice: Double = 1,
                weeklyDrift: Double = -0.004,
                weeklySigma: Double = 0.16,
                minPrice: Double = 0.04,
                maxPrice: Double = 60,
                spread: Double = 0.02
            ) {
                self.startingPrice = startingPrice
                self.weeklyDrift = weeklyDrift
                self.weeklySigma = weeklySigma
                self.minPrice = minPrice
                self.maxPrice = maxPrice
                self.spread = spread
            }
        }

        // MARK: The doctor

        /// A named thing the founder is living with. Causes are read off
        /// the state rather than rolled, so a diagnosis is always the
        /// consequence of something the player chose.
        public struct AssetAilmentDef: Codable, Equatable, Sendable, Identifiable {
            public var id: String
            public var name: String
            /// What the doctor's office says caused it.
            public var cause: String
            /// What it feels like, in one line.
            public var note: String
            public var energy: Double
            public var health: Double
            public var mood: Double
            public var relationships: Double
            public var treatmentCost: Int
            /// Days of treatment before it clears.
            public var treatmentDays: Int
            /// Consecutive crunch weeks that bring it on. 0 = not this.
            public var crunchWeeks: Int
            /// Consecutive days under 30 mood that bring it on.
            public var lowMoodDays: Int
            /// Consecutive days under 40 health that bring it on.
            public var lowHealthDays: Int
            /// The vice, and the dependency, that brings it on.
            public var viceID: String?
            public var viceDependency: Double
            /// Burnouts inside the economy's burnout window that bring it
            /// on.
            public var burnouts: Int

            public init(
                id: String, name: String, cause: String, note: String,
                energy: Double = 0, health: Double = 0, mood: Double = 0, relationships: Double = 0,
                treatmentCost: Int, treatmentDays: Int,
                crunchWeeks: Int = 0, lowMoodDays: Int = 0, lowHealthDays: Int = 0,
                viceID: String? = nil, viceDependency: Double = 0, burnouts: Int = 0
            ) {
                self.id = id
                self.name = name
                self.cause = cause
                self.note = note
                self.energy = energy
                self.health = health
                self.mood = mood
                self.relationships = relationships
                self.treatmentCost = treatmentCost
                self.treatmentDays = treatmentDays
                self.crunchWeeks = crunchWeeks
                self.lowMoodDays = lowMoodDays
                self.lowHealthDays = lowHealthDays
                self.viceID = viceID
                self.viceDependency = viceDependency
                self.burnouts = burnouts
            }
        }

        /// An hour a week, and what it is worth.
        public struct AssetTherapyDef: Codable, Equatable, Sendable {
            public var cost: Int
            /// Taken off every vice's dependency.
            public var viceRelief: Double
            public var mood: Double
            public var energy: Double
            public var cooldownDays: Int

            public init(
                cost: Int = 220, viceRelief: Double = 6,
                mood: Double = 5, energy: Double = 2, cooldownDays: Int = 7
            ) {
                self.cost = cost
                self.viceRelief = viceRelief
                self.mood = mood
                self.energy = energy
                self.cooldownDays = cooldownDays
            }
        }

        // MARK: The vices

        /// A thing that creeps in. Dependency is 0…100; the drifts below
        /// are what it costs a day *at 100*, scaled linearly down to
        /// nothing at zero.
        public struct AssetViceDef: Codable, Equatable, Sendable, Identifiable {
            public var id: String
            public var name: String
            /// What it looks like from outside.
            public var note: String
            /// Added the week a product ships — the launch party.
            public var perLaunch: Double
            /// Added for a week spent on crunch.
            public var perCrunchWeek: Double
            /// Added per hand at the casino, on top of the game's own.
            public var perGamble: Double
            /// Taken off every week, before anything is added.
            public var weeklyDecay: Double
            public var moodDrift: Double
            public var healthDrift: Double
            public var energyDrift: Double
            public var relationshipsDrift: Double
            /// Where somebody who loves you says something.
            public var interventionAt: Double

            public init(
                id: String, name: String, note: String,
                perLaunch: Double = 0, perCrunchWeek: Double = 0, perGamble: Double = 0,
                weeklyDecay: Double = 1,
                moodDrift: Double = 0, healthDrift: Double = 0,
                energyDrift: Double = 0, relationshipsDrift: Double = 0,
                interventionAt: Double = 60
            ) {
                self.id = id
                self.name = name
                self.note = note
                self.perLaunch = perLaunch
                self.perCrunchWeek = perCrunchWeek
                self.perGamble = perGamble
                self.weeklyDecay = weeklyDecay
                self.moodDrift = moodDrift
                self.healthDrift = healthDrift
                self.energyDrift = energyDrift
                self.relationshipsDrift = relationshipsDrift
                self.interventionAt = interventionAt
            }
        }

        /// A run of evenings spent not doing it.
        public struct AssetQuitDef: Codable, Equatable, Sendable {
            /// Evenings the run needs.
            public var evenings: Int
            /// Dependency each evening takes off.
            public var perEvening: Double
            /// Mood each evening costs while the run is on.
            public var moodCost: Double
            /// Chance an evening goes wrong instead.
            public var relapseChance: Double
            /// What a relapse puts back.
            public var relapseGain: Double
            /// Mood the finished run is worth.
            public var successMood: Double
            /// Days a run may be left alone before it lapses on its own.
            public var lapseDays: Int

            public init(
                evenings: Int = 5, perEvening: Double = 12, moodCost: Double = 3,
                relapseChance: Double = 0.22, relapseGain: Double = 8,
                successMood: Double = 9, lapseDays: Int = 21
            ) {
                self.evenings = evenings
                self.perEvening = perEvening
                self.moodCost = moodCost
                self.relapseChance = relapseChance
                self.relapseGain = relapseGain
                self.successMood = successMood
                self.lapseDays = lapseDays
            }
        }

        // MARK: The block

        public var cars: [AssetDef]
        public var properties: [AssetDef]
        public var pets: [AssetDef]
        public var games: [AssetGameDef]
        public var lottery: AssetLotteryDef
        public var crypto: AssetCryptoDef
        public var ailments: [AssetAilmentDef]
        public var therapy: AssetTherapyDef
        public var vices: [AssetViceDef]
        public var quitting: AssetQuitDef
        /// Names a pet is given, drawn on `socialRNG` when it is adopted.
        public var petNames: [String]
        /// What a broken thing is worth against a working one.
        public var brokenResaleFactor: Double
        /// Dollars a week the casino will take from one founder. Not a
        /// moral position: a cap keeps a bad night from being a run-ending
        /// one, and keeps the wallet's arithmetic inside `Int`.
        public var weeklyStakeCap: Int
        /// Mood the founder loses the day something is stolen.
        public var lossMoodPenalty: Double
        /// Below this mood for `AssetAilmentDef.lowMoodDays`, the doctor
        /// starts writing things down.
        public var lowMoodLine: Double
        public var lowHealthLine: Double

        public init(
            cars: [AssetDef] = Self.defaultCars,
            properties: [AssetDef] = Self.defaultProperties,
            pets: [AssetDef] = Self.defaultPets,
            games: [AssetGameDef] = Self.defaultGames,
            lottery: AssetLotteryDef = AssetLotteryDef(),
            crypto: AssetCryptoDef = AssetCryptoDef(),
            ailments: [AssetAilmentDef] = Self.defaultAilments,
            therapy: AssetTherapyDef = AssetTherapyDef(),
            vices: [AssetViceDef] = Self.defaultVices,
            quitting: AssetQuitDef = AssetQuitDef(),
            petNames: [String] = Self.defaultPetNames,
            brokenResaleFactor: Double = 0.55,
            weeklyStakeCap: Int = 25_000,
            lossMoodPenalty: Double = 9,
            lowMoodLine: Double = 30,
            lowHealthLine: Double = 40
        ) {
            self.cars = cars
            self.properties = properties
            self.pets = pets
            self.games = games
            self.lottery = lottery
            self.crypto = crypto
            self.ailments = ailments
            self.therapy = therapy
            self.vices = vices
            self.quitting = quitting
            self.petNames = petNames
            self.brokenResaleFactor = brokenResaleFactor
            self.weeklyStakeCap = weeklyStakeCap
            self.lossMoodPenalty = lossMoodPenalty
            self.lowMoodLine = lowMoodLine
            self.lowHealthLine = lowHealthLine
        }

        // Every key decode-if-present, so a balance file may override one
        // table (the cars, say) without restating the other eleven.
        private enum CodingKeys: String, CodingKey {
            case cars, properties, pets, games, lottery, crypto, ailments
            case therapy, vices, quitting, petNames, brokenResaleFactor
            case weeklyStakeCap, lossMoodPenalty, lowMoodLine, lowHealthLine
        }

        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.init(
                cars: try c.decodeIfPresent([AssetDef].self, forKey: .cars) ?? Self.defaultCars,
                properties: try c.decodeIfPresent([AssetDef].self, forKey: .properties)
                    ?? Self.defaultProperties,
                pets: try c.decodeIfPresent([AssetDef].self, forKey: .pets) ?? Self.defaultPets,
                games: try c.decodeIfPresent([AssetGameDef].self, forKey: .games) ?? Self.defaultGames,
                lottery: try c.decodeIfPresent(AssetLotteryDef.self, forKey: .lottery) ?? AssetLotteryDef(),
                crypto: try c.decodeIfPresent(AssetCryptoDef.self, forKey: .crypto) ?? AssetCryptoDef(),
                ailments: try c.decodeIfPresent([AssetAilmentDef].self, forKey: .ailments)
                    ?? Self.defaultAilments,
                therapy: try c.decodeIfPresent(AssetTherapyDef.self, forKey: .therapy) ?? AssetTherapyDef(),
                vices: try c.decodeIfPresent([AssetViceDef].self, forKey: .vices) ?? Self.defaultVices,
                quitting: try c.decodeIfPresent(AssetQuitDef.self, forKey: .quitting) ?? AssetQuitDef(),
                petNames: try c.decodeIfPresent([String].self, forKey: .petNames) ?? Self.defaultPetNames,
                brokenResaleFactor: try c.decodeIfPresent(Double.self, forKey: .brokenResaleFactor) ?? 0.55,
                weeklyStakeCap: try c.decodeIfPresent(Int.self, forKey: .weeklyStakeCap) ?? 25_000,
                lossMoodPenalty: try c.decodeIfPresent(Double.self, forKey: .lossMoodPenalty) ?? 9,
                lowMoodLine: try c.decodeIfPresent(Double.self, forKey: .lowMoodLine) ?? 30,
                lowHealthLine: try c.decodeIfPresent(Double.self, forKey: .lowHealthLine) ?? 40
            )
        }

        /// The shipped catalog. Like `bugHunt`, the default is not
        /// "switched off" — there is nothing to switch off until the
        /// player opens the screen — so a balance file with no `"assets"`
        /// object still gets the game that ships.
        public static let `default` = AssetsBalance()

        // MARK: Lookups

        /// Everything that can be bought, in one list.
        public var everything: [AssetDef] { cars + properties + pets }

        public func asset(_ id: String) -> AssetDef? {
            everything.first { $0.id == id }
        }

        public func game(_ id: String) -> AssetGameDef? {
            games.first { $0.id == id }
        }

        public func ailment(_ id: String) -> AssetAilmentDef? {
            ailments.first { $0.id == id }
        }

        public func vice(_ id: String) -> AssetViceDef? {
            vices.first { $0.id == id }
        }

        // MARK: The shipped tables

        public static let defaultCars: [AssetDef] = [
            AssetDef(
                id: "hatchback", kind: "car",
                name: "Second-hand hatchback",
                note: "One previous owner, who smoked.",
                price: 4000, weeklyCost: 40,
                faultChance: 0.020, lossChance: 0.002,
                repairCost: 400, resaleFraction: 0.55,
                moodDrift: 0.10, prestige: 0
            ),
            AssetDef(
                id: "estate", kind: "car",
                name: "The family estate",
                note: "Room in the back for a life you have not had yet.",
                price: 12_000, weeklyCost: 70,
                faultChance: 0.012, lossChance: 0.004,
                repairCost: 900, resaleFraction: 0.60,
                moodDrift: 0.20, prestige: 1
            ),
            AssetDef(
                id: "coupe", kind: "car",
                name: "The German coupé",
                note: "Nobody at the office says anything. Everybody notices.",
                price: 45_000, weeklyCost: 160,
                faultChance: 0.008, lossChance: 0.010,
                repairCost: 2400, resaleFraction: 0.65,
                moodDrift: 0.35, prestige: 3
            ),
            AssetDef(
                id: "supercar", kind: "car",
                name: "The one with the doors",
                note: "You have driven it to the shops twice and told nobody.",
                price: 180_000, weeklyCost: 420,
                faultChance: 0.015, lossChance: 0.018,
                repairCost: 9000, resaleFraction: 0.70,
                moodDrift: 0.50, prestige: 6
            ),
        ]

        public static let defaultProperties: [AssetDef] = [
            AssetDef(
                id: "flatToLet", kind: "property",
                name: "A flat to let out",
                note: "Two bedrooms, one boiler, somebody else's Sunday.",
                price: 90_000, weeklyCost: 120, weeklyRent: 520,
                faultChance: 0.006, lossChance: 0,
                repairCost: 6000, resaleFraction: 0.90,
                moodDrift: 0.05, prestige: 2
            ),
            AssetDef(
                id: "cabin", kind: "property",
                name: "The cabin",
                note: "Four hours away. You have been twice. It helps anyway.",
                price: 150_000, weeklyCost: 180,
                faultChance: 0.009, lossChance: 0,
                repairCost: 9000, resaleFraction: 0.85,
                moodDrift: 0.40, prestige: 3
            ),
        ]

        public static let defaultPets: [AssetDef] = [
            AssetDef(
                id: "dog", kind: "pet",
                name: "A dog",
                note: "Waits by the door whatever time you get in.",
                price: 900, weeklyCost: 45,
                faultChance: 0.010, lossChance: 0.001,
                repairCost: 700, resaleFraction: 0,
                moodDrift: 0.45, prestige: 0
            ),
            AssetDef(
                id: "cat", kind: "pet",
                name: "A cat",
                note: "Sits on the laptop. This is the arrangement.",
                price: 400, weeklyCost: 25,
                faultChance: 0.008, lossChance: 0.002,
                repairCost: 500, resaleFraction: 0,
                moodDrift: 0.30, prestige: 0
            ),
            AssetDef(
                id: "tortoise", kind: "pet",
                name: "A tortoise",
                note: "Will outlive the company. Possibly you.",
                price: 250, weeklyCost: 8,
                faultChance: 0.002, lossChance: 0.0005,
                repairCost: 300, resaleFraction: 0,
                moodDrift: 0.12, prestige: 0
            ),
        ]

        public static let defaultGames: [AssetGameDef] = [
            AssetGameDef(
                id: "blackjack", name: "Blackjack",
                note: "The best odds in the building, which is not a compliment.",
                minStake: 50, maxStake: 5000,
                winChance: 0.48, payout: 2.0, viceGain: 4
            ),
            AssetGameDef(
                id: "roulette", name: "Roulette, on red",
                note: "There is a green one. There is always a green one.",
                minStake: 50, maxStake: 5000,
                winChance: 0.474, payout: 2.0, viceGain: 5
            ),
            AssetGameDef(
                id: "slots", name: "The machines",
                note: "Fourteen times your money, one time in seventeen.",
                minStake: 20, maxStake: 500,
                winChance: 0.06, payout: 14.0, viceGain: 7
            ),
        ]

        public static let defaultAilments: [AssetAilmentDef] = [
            AssetAilmentDef(
                id: "burnoutSyndrome", name: "Burnout",
                cause: "Two collapses inside a year",
                note: "Not tiredness. The other thing, that sleep does not fix.",
                energy: -0.5, mood: -0.3,
                treatmentCost: 1800, treatmentDays: 7,
                burnouts: 2
            ),
            AssetAilmentDef(
                id: "rsi", name: "RSI",
                cause: "Three straight weeks on crunch",
                note: "Your right hand has opinions about the mornings.",
                energy: -0.2, mood: -0.25,
                treatmentCost: 900, treatmentDays: 4,
                crunchWeeks: 3
            ),
            AssetAilmentDef(
                id: "insomnia", name: "Insomnia",
                cause: "A fortnight of bad weeks",
                note: "You are awake at four and the ceiling is very interesting.",
                energy: -0.45, mood: -0.1,
                treatmentCost: 1200, treatmentDays: 5,
                lowMoodDays: 14
            ),
            AssetAilmentDef(
                id: "badBack", name: "A bad back",
                cause: "Three weeks of running yourself down",
                note: "You now know the word for the muscle. Everyone does eventually.",
                health: -0.2, mood: -0.2,
                treatmentCost: 1500, treatmentDays: 6,
                lowHealthDays: 21
            ),
            AssetAilmentDef(
                id: "liverWarning", name: "A liver the doctor mentions",
                cause: "Drink, at seventy and climbing",
                note: "She says it twice, in case the first time did not land.",
                energy: -0.15, health: -0.4,
                treatmentCost: 2600, treatmentDays: 9,
                viceID: "drink", viceDependency: 70
            ),
        ]

        public static let defaultVices: [AssetViceDef] = [
            AssetViceDef(
                id: "drink", name: "Drink",
                note: "It started as the one after a launch.",
                perLaunch: 6, perCrunchWeek: 3, perGamble: 1,
                weeklyDecay: 1.5,
                moodDrift: -0.5, healthDrift: -0.6, relationshipsDrift: -0.2,
                interventionAt: 60
            ),
            AssetViceDef(
                id: "caffeine", name: "Caffeine",
                note: "Six a day, and the sixth does nothing.",
                perLaunch: 1, perCrunchWeek: 4,
                weeklyDecay: 2.0,
                moodDrift: -0.2, healthDrift: -0.3, energyDrift: -0.25,
                interventionAt: 70
            ),
            AssetViceDef(
                id: "gambling", name: "Gambling",
                note: "You are not chasing it. You are managing it.",
                perGamble: 6,
                weeklyDecay: 1.0,
                moodDrift: -0.6, healthDrift: -0.1, relationshipsDrift: -0.3,
                interventionAt: 55
            ),
            AssetViceDef(
                id: "phone", name: "The phone",
                note: "You have checked it since you started reading this.",
                perLaunch: 2, perCrunchWeek: 2,
                weeklyDecay: 1.2,
                moodDrift: -0.35, healthDrift: -0.05,
                energyDrift: -0.15, relationshipsDrift: -0.25,
                interventionAt: 65
            ),
        ]

        public static let defaultPetNames: [String] = [
            "Biscuit", "Comma", "Dividend", "Ferris", "Gatsby", "Hobbes",
            "Latency", "Maple", "Nimbus", "Otto", "Pixel", "Quarter",
            "Rusty", "Sprocket", "Tuesday", "Waffle",
        ]
    }
}

// Lets `BalanceConfig`'s synthesized decoder read a balance file with no
// `"assets"` object.
extension KeyedDecodingContainer {
    func decode(
        _ type: BalanceConfig.AssetsBalance.Type,
        forKey key: Key
    ) throws -> BalanceConfig.AssetsBalance {
        try decodeIfPresent(type, forKey: key) ?? .default
    }
}
