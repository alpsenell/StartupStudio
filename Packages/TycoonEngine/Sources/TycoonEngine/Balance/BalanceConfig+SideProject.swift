import Foundation

// Iteration 9 — L5. The side-project catalog: five tracks, four chapters
// each, and what a chapter pays when the founder finishes it.
//
// Same shape as `BalanceConfig+Founder.swift`: a nested block that decodes
// as a whole from its own `"sideProject"` object in `Balance.json`, and
// `.default` when the object is absent.
//
// Identity: unlike `founder` or `networking`, `.default` here ships the
// *real* catalog rather than a switched-off one, and that is still exactly
// neutral — every number in it is behind `.startSideProject`, an action no
// pacing bot and no untouched save has ever sent. A run with
// `life.sideProject == nil` never reads a byte of this file.

extension BalanceConfig {

    /// The five side-project tracks and what each chapter of each one
    /// costs and pays.
    public struct SideProjectBalance: Codable, Equatable, Sendable {

        /// One milestone: a number of evenings, and what lands when the
        /// last of them is done.
        public struct ChapterDef: Codable, Equatable, Sendable {
            /// The chapter's name on the strip.
            public var title: String
            /// One line saying what this chapter *is*, before it is done.
            public var blurb: String
            /// Evenings it takes a founder of exactly average attributes.
            /// A trained founder needs fewer; an untrained one more.
            public var sessions: Double

            /// Company reputation the milestone is worth (0...100 scale,
            /// the same one `ProgressionSystem` pays goals in).
            public var reputation: Double
            /// Personal money in (or, negative, out) on completion.
            public var wallet: Int
            /// A `ProgressionPerk` raw value, granted permanently.
            /// Ignored when it is not one.
            public var perk: String?
            /// Meter deltas the finish is worth.
            public var energy: Double
            public var health: Double
            public var mood: Double
            public var relationships: Double

            /// The trade-press line, when the milestone is loud enough to
            /// make one. Posted as `.industryNews`, which changes nothing.
            public var press: String?
            /// The line the office thread gets.
            public var officeLine: String
            /// The line the partner thread gets. They noticed too.
            public var partnerLine: String

            /// The finish is a coin flip on the founder's `socialRNG`:
            /// `walletUpside` on a good roll, the declared `wallet` on a
            /// bad one, at `upsideChance`. Zero chance means no roll at
            /// all, which is every chapter but one.
            public var upsideChance: Double
            public var walletUpside: Int
            public var pressUpside: String?

            public init(
                title: String,
                blurb: String,
                sessions: Double,
                reputation: Double = 0,
                wallet: Int = 0,
                perk: String? = nil,
                energy: Double = 0,
                health: Double = 0,
                mood: Double = 0,
                relationships: Double = 0,
                press: String? = nil,
                officeLine: String,
                partnerLine: String,
                upsideChance: Double = 0,
                walletUpside: Int = 0,
                pressUpside: String? = nil
            ) {
                self.title = title
                self.blurb = blurb
                self.sessions = sessions
                self.reputation = reputation
                self.wallet = wallet
                self.perk = perk
                self.energy = energy
                self.health = health
                self.mood = mood
                self.relationships = relationships
                self.press = press
                self.officeLine = officeLine
                self.partnerLine = partnerLine
                self.upsideChance = upsideChance
                self.walletUpside = walletUpside
                self.pressUpside = pressUpside
            }
        }

        /// One track: what it runs on, what an evening of it costs, and
        /// its four chapters.
        public struct TrackDef: Codable, Equatable, Sendable {
            /// The line under the name on the picker.
            public var blurb: String
            /// `SideProjectDriver` raw values, averaged. This is the
            /// attribute (or meter) the track actually runs on.
            public var drivers: [String]
            /// Wallet money one evening costs.
            public var sessionCost: Int
            /// Meter deltas one evening is worth.
            public var sessionEnergy: Double
            public var sessionHealth: Double
            public var sessionMood: Double
            /// `ActivitySceneStyle` raw value: the pixel vignette the app
            /// plays for an evening on this track. The engine never draws
            /// anything; it just names the scene so the catalog owns it.
            public var scene: String
            /// The four chapters, in order.
            public var chapters: [ChapterDef]
            /// The line the biography gets, with `%@` for the year.
            public var biographyLine: String

            public init(
                blurb: String,
                drivers: [String],
                sessionCost: Int,
                sessionEnergy: Double,
                sessionHealth: Double = 0,
                sessionMood: Double,
                scene: String,
                chapters: [ChapterDef],
                biographyLine: String
            ) {
                self.blurb = blurb
                self.drivers = drivers
                self.sessionCost = sessionCost
                self.sessionEnergy = sessionEnergy
                self.sessionHealth = sessionHealth
                self.sessionMood = sessionMood
                self.scene = scene
                self.chapters = chapters
                self.biographyLine = biographyLine
            }
        }

        /// Keyed by `SideProjectTrack` raw value.
        public var tracks: [String: TrackDef]
        /// How hard the driving attributes push. `0.6` means a founder at
        /// zero works at ×0.7 and one at a hundred at ×1.3, centred on
        /// `founder.skillMidpoint` so the untrained founder is exactly the
        /// catalog's own evening count.
        public var attributeStrength: Double
        /// Floor on that factor, so a founder in a bad way still finishes.
        public var minFactor: Double

        /// The marathon (and only the marathon) creeps forward on days the
        /// founder trains anyway: this much of a chapter per day, while a
        /// gym session is within `gymWindowDays` or the gym is the plan.
        /// The one thing on this tab that moves without an evening.
        public var gymProgressPerDay: Double
        public var gymWindowDays: Int

        public init(
            tracks: [String: TrackDef],
            attributeStrength: Double = 0.6,
            minFactor: Double = 0.4,
            gymProgressPerDay: Double = 0.02,
            gymWindowDays: Int = 4
        ) {
            self.tracks = tracks
            self.attributeStrength = attributeStrength
            self.minFactor = minFactor
            self.gymProgressPerDay = gymProgressPerDay
            self.gymWindowDays = gymWindowDays
        }

        public func track(_ id: String) -> TrackDef? { tracks[id] }
        public func track(_ track: SideProjectTrack) -> TrackDef? { tracks[track.rawValue] }

        /// The attribute multiplier on a track's evenings.
        public func factor(
            for def: TrackDef,
            life: LifeState,
            founder: FounderBalance
        ) -> Double {
            let values = def.drivers.compactMap(SideProjectDriver.init(rawValue:))
                .map { $0.value(in: life) }
            guard !values.isEmpty else { return 1 }
            let average = values.reduce(0, +) / Double(values.count)
            let raw = 1 + attributeStrength * (average - founder.skillMidpoint) / 100
            return max(minFactor, raw)
        }

        /// The tracks in the shipped order, skipping any the balance
        /// dropped.
        public var shippedOrder: [SideProjectTrack] {
            SideProjectTrack.allCases.filter { tracks[$0.rawValue] != nil }
        }

        /// The shipped catalog. See the note at the top of the file for
        /// why this is not switched off: nothing here runs until the
        /// founder starts a project.
        public static let `default` = SideProjectBalance(tracks: shippedTracks)
    }
}

// MARK: - The shipped catalog

extension BalanceConfig.SideProjectBalance {
    typealias Chapter = ChapterDef

    /// Five tracks, four chapters, seventeen to twenty evenings each — a
    /// season's worth of the founder's own time, set against a partner
    /// sliding and a course they could have taken instead.
    static let shippedTracks: [String: TrackDef] = [

        // MARK: The novel — free, slow, and the only one that pays a perk
        // for being *known* rather than for making money.
        SideProjectTrack.novel.rawValue: TrackDef(
            blurb: "Ninety thousand words nobody asked you for.",
            drivers: [SideProjectDriver.conversation.rawValue],
            sessionCost: 0,
            sessionEnergy: -5,
            sessionMood: 3,
            scene: "hobby",
            chapters: [
                Chapter(
                    title: "The first hundred pages",
                    blurb: "Get something on paper before you talk yourself out of it.",
                    sessions: 4,
                    reputation: 1,
                    mood: 5,
                    officeLine: "Somebody saw your document open at 1am. It was not a deck.",
                    partnerLine: "A hundred pages. I read four of them. Keep going."
                ),
                Chapter(
                    title: "The middle",
                    blurb: "The part everyone abandons. Nothing happens for forty pages.",
                    sessions: 6,
                    reputation: 1,
                    mood: 3,
                    officeLine: "You have been quiet in the evenings. Something is being written.",
                    partnerLine: "You got through the middle. Most people don't."
                ),
                Chapter(
                    title: "The draft",
                    blurb: "An agent read it on a train and emailed you from the platform.",
                    sessions: 5,
                    reputation: 2,
                    wallet: 500,
                    mood: 6,
                    press: "Tech founder signs a two-book deal, which is not a pivot.",
                    officeLine: "There is an agent. There is an advance. It is not a lot.",
                    partnerLine: "An advance. A real one. We are framing the email."
                ),
                Chapter(
                    title: "Published",
                    blurb: "It exists, in shops, with your name down the spine.",
                    sessions: 5,
                    reputation: 4,
                    wallet: 4000,
                    perk: ProgressionPerk.pressContacts.rawValue,
                    mood: 12,
                    relationships: 4,
                    press: "The founder who wrote a novel takes every call now.",
                    officeLine: "Your book is out. Journalists who ignored us for years are calling.",
                    partnerLine: "It's on the shelf by the door. I keep turning it face out."
                ),
            ],
            biographyLine: "You wrote a novel in year %@, and it got published."
        ),

        // MARK: The band — the relationships track. Cheap, loud, and the
        // biggest mood swing on the tab.
        SideProjectTrack.band.rawValue: TrackDef(
            blurb: "Four people, a rehearsal room, and one good song.",
            drivers: [
                SideProjectDriver.conversation.rawValue,
                SideProjectDriver.leadership.rawValue,
            ],
            sessionCost: 40,
            sessionEnergy: -6,
            sessionMood: 5,
            scene: "friends",
            chapters: [
                Chapter(
                    title: "Four people in a room",
                    blurb: "Finding three others who will show up on a Tuesday.",
                    sessions: 3,
                    mood: 6,
                    relationships: 4,
                    officeLine: "You have a band. Nobody at work is sure how to react.",
                    partnerLine: "You came home loud and happy. Keep the band."
                ),
                Chapter(
                    title: "A set worth playing",
                    blurb: "Forty minutes that hold together end to end.",
                    sessions: 5,
                    mood: 5,
                    relationships: 3,
                    officeLine: "Forty minutes of material. The drummer is the problem.",
                    partnerLine: "I heard the demo. The third one is the good one."
                ),
                Chapter(
                    title: "The first gig",
                    blurb: "A room above a pub, sixty people, most of them yours.",
                    sessions: 5,
                    reputation: 1,
                    wallet: 200,
                    mood: 10,
                    relationships: 6,
                    press: "A founder played a pub gig on Friday and was fine on Monday.",
                    officeLine: "Half the team came to the gig. They will not let this go.",
                    partnerLine: "You were good. I filmed the whole of the last one."
                ),
                Chapter(
                    title: "The record",
                    blurb: "Nine tracks, a weekend in a studio, a cover you drew.",
                    sessions: 6,
                    reputation: 3,
                    wallet: 1500,
                    mood: 14,
                    relationships: 6,
                    press: "The record is out. It is better than it has any right to be.",
                    officeLine: "The record is out. Somebody put it on in the office.",
                    partnerLine: "It's finished. You made a record. I'm telling everyone."
                ),
            ],
            biographyLine: "You made a record in year %@, with a band that stayed together."
        ),

        // MARK: The marathon — the only track that moves without an
        // evening, and the only one that pays in health.
        SideProjectTrack.marathon.rawValue: TrackDef(
            blurb: "Forty-two kilometres, one Sunday, on legs you built.",
            drivers: [SideProjectDriver.health.rawValue],
            sessionCost: 0,
            sessionEnergy: -10,
            sessionHealth: 3,
            sessionMood: 3,
            scene: "gymSession",
            chapters: [
                Chapter(
                    title: "Five kilometres",
                    blurb: "Without stopping. That is the whole of this chapter.",
                    sessions: 3,
                    health: 5,
                    mood: 4,
                    officeLine: "You took the stairs today and did not think about it.",
                    partnerLine: "Five without stopping. I'm impressed and a bit annoyed."
                ),
                Chapter(
                    title: "The half",
                    blurb: "Twenty-one kilometres, and the knee that you now know about.",
                    sessions: 5,
                    health: 6,
                    mood: 5,
                    officeLine: "Half marathon done. You have opinions about socks now.",
                    partnerLine: "Twenty-one kilometres. You slept for eleven hours."
                ),
                Chapter(
                    title: "The long runs",
                    blurb: "Sunday mornings that eat the whole morning.",
                    sessions: 6,
                    health: 6,
                    mood: 3,
                    officeLine: "Thirty-two kilometres on Sunday. You were quiet on Monday.",
                    partnerLine: "You are gone every Sunday morning. I've started coming."
                ),
                Chapter(
                    title: "Race day",
                    blurb: "The finish line, a foil blanket, and a time you will quote.",
                    sessions: 4,
                    reputation: 1,
                    wallet: -120,
                    health: 10,
                    mood: 16,
                    relationships: 5,
                    press: "A founder ran a marathon and did not once mention discipline.",
                    officeLine: "You finished the marathon. The whole office watched the tracker.",
                    partnerLine: "I saw you at 38k. You looked terrible. You finished."
                ),
            ],
            biographyLine: "You ran a marathon in year %@, and finished it."
        ),

        // MARK: The weekend app — the technical track, the biggest cash
        // payout, and the one that never touches `products`.
        SideProjectTrack.weekendApp.rawValue: TrackDef(
            blurb: "A small thing you build for yourself, badly, on Sundays.",
            drivers: [SideProjectDriver.technical.rawValue],
            sessionCost: 60,
            sessionEnergy: -7,
            sessionMood: 2,
            scene: "cinema",
            chapters: [
                Chapter(
                    title: "A weekend prototype",
                    blurb: "One screen that does one thing, for an audience of you.",
                    sessions: 3,
                    mood: 6,
                    officeLine: "You shipped something in a weekend. Remember that feeling.",
                    partnerLine: "You built a thing for fun. You were smiling at a laptop."
                ),
                Chapter(
                    title: "Ten users",
                    blurb: "Strangers. Actual strangers, using it, unprompted.",
                    sessions: 4,
                    reputation: 1,
                    mood: 4,
                    officeLine: "Ten strangers use your weekend thing. No marketing spend.",
                    partnerLine: "Ten people you don't know. That's ten more than most."
                ),
                Chapter(
                    title: "On the front page",
                    blurb: "Somebody posted it. It stayed up all day.",
                    sessions: 5,
                    reputation: 3,
                    wallet: 400,
                    mood: 8,
                    press: "A side project from a working founder is today's front page.",
                    officeLine: "Your weekend thing is on the front page. The servers held.",
                    partnerLine: "Front page. You refreshed it four hundred times, I counted."
                ),
                Chapter(
                    title: "Bought for a small number",
                    blurb: "Someone wants it. Not life-changing money. Clean money.",
                    sessions: 5,
                    reputation: 2,
                    wallet: 9000,
                    perk: ProgressionPerk.talentMagnet.rawValue,
                    mood: 10,
                    press: "The weekend app sold. Engineers noticed who built it.",
                    officeLine: "The weekend app sold. Three good engineers emailed us after.",
                    partnerLine: "You sold it. We are not moving house, but dinner is on you."
                ),
            ],
            biographyLine: "You built a weekend app in year %@, and sold it."
        ),

        // MARK: The restaurant — the money track. It eats the wallet all
        // the way through and the last chapter is a coin flip.
        SideProjectTrack.restaurant.rawValue: TrackDef(
            blurb: "Eighteen covers, one room, and everything you have saved.",
            drivers: [
                SideProjectDriver.marketKnowledge.rawValue,
                SideProjectDriver.finance.rawValue,
            ],
            sessionCost: 220,
            sessionEnergy: -8,
            sessionMood: 4,
            scene: "restaurant",
            chapters: [
                Chapter(
                    title: "The lease",
                    blurb: "A room on a street that is about to be good.",
                    sessions: 4,
                    wallet: -2000,
                    mood: 6,
                    officeLine: "You signed a lease on a restaurant. This is a real thing now.",
                    partnerLine: "We signed a lease. I am terrified and I love it."
                ),
                Chapter(
                    title: "The menu",
                    blurb: "Nine dishes. Six of them are the ones you cook anyway.",
                    sessions: 5,
                    mood: 8,
                    relationships: 3,
                    officeLine: "There is a menu. You have cooked it at us four times.",
                    partnerLine: "The menu is nine things and every one of them works."
                ),
                Chapter(
                    title: "Opening night",
                    blurb: "Full room, one broken fridge, and nobody knew.",
                    sessions: 5,
                    reputation: 2,
                    mood: 12,
                    relationships: 6,
                    press: "A founder opened a restaurant. The reviews are for the food.",
                    officeLine: "Opening night was full. The fridge died. Nobody noticed.",
                    partnerLine: "Full room on the first night. You cried in the walk-in."
                ),
                Chapter(
                    title: "The first year",
                    blurb: "Twelve months of covers. It either works or it doesn't.",
                    sessions: 6,
                    reputation: 2,
                    wallet: -9000,
                    mood: 4,
                    press: "The restaurant closed after a year. The chef went back to software.",
                    officeLine: "The restaurant closed. It was a good room for a year.",
                    partnerLine: "We tried it. I would do the whole thing again.",
                    upsideChance: 0.55,
                    walletUpside: 18000,
                    pressUpside: "Year one, in profit, and a booking list two months long."
                ),
            ],
            biographyLine: "You opened a restaurant in year %@, and ran it for a year."
        ),
    ]
}

// Lets `BalanceConfig`'s synthesized decoder read a balance file with no
// `"sideProject"` object — the same trick `BalanceConfig+Founder.swift`
// uses for its three blocks.
extension KeyedDecodingContainer {
    func decode(
        _ type: BalanceConfig.SideProjectBalance.Type,
        forKey key: Key
    ) throws -> BalanceConfig.SideProjectBalance {
        try decodeIfPresent(type, forKey: key) ?? .default
    }
}
