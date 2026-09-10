import Foundation

// Iteration 12 — J2 (the record crosses over). What the founder's record
// costs the company: the board's line at a review, the key-person clause
// on a term sheet, the premium a bad name puts on every ask, and the
// spotlight fame shines on everything the founder hid.
//
// Every number here multiplies or adds to something that is exactly zero
// for a founder with no case, no beef, no cancellation, no mean act on
// staff, no firing with cause, no guilty verdict and no fame — which is
// every pacing bot and every fixture. So a clean run is bit-for-bit the
// run it was before this file existed, whatever the values say.

extension BalanceConfig {

    // MARK: - Standing

    public struct StandingRecordBalance: Codable, Equatable, Sendable {
        // The board reads the papers: points of board pressure at a review.
        /// Per open case with the founder as the defendant.
        public var boardOpenCase: Double
        /// Per guilty verdict handed down inside the quarter.
        public var boardGuiltyVerdict: Double
        /// Per round of a public beef still running.
        public var boardBeefRound: Double
        /// For a cancellation nobody has answered.
        public var boardCancellation: Double
        /// The most the founder's quarter adds to one review.
        public var boardCap: Double
        /// With no board, a term sheet that arrives during an open case is
        /// priced at this fraction of the rolled offer.
        public var keyPersonClauseFactor: Double

        // Your name gets around: the 0…100 score recruiters hear.
        public var nameNotorietyWeight: Double
        public var nameFiredWithCause: Double
        public var nameMeanAct: Double
        public var nameMeanActCap: Double
        /// How long a mean act on staff is remembered, in days.
        public var nameMeanActWindowDays: Int
        public var nameGuiltyVerdict: Double
        /// Taken off per fame level: fame launders a name.
        public var nameFameLevel: Double
        /// Taken off per alumnus who still likes you.
        public var nameAlumnusVouch: Double
        /// The rapport at which an alumnus vouches.
        public var vouchRapport: Double
        /// Asks read `× (1 + name / askDivisor)`.
        public var askDivisor: Double
        /// At this name the best candidate will not come in.
        public var refuseAt: Double

        // Fame is a spotlight.
        /// `spotlight = 1 + spotlightPerRung × fame level`.
        public var spotlightPerRung: Double
        /// The weekly base rate at which a payment through a backer is
        /// found. Iteration 11's `Crime.launderDiscovery` constant, moved
        /// here with the same value.
        public var launderDiscovery: Double

        public init(
            boardOpenCase: Double = 8,
            boardGuiltyVerdict: Double = 12,
            boardBeefRound: Double = 4,
            boardCancellation: Double = 6,
            boardCap: Double = 25,
            keyPersonClauseFactor: Double = 0.85,
            nameNotorietyWeight: Double = 0.5,
            nameFiredWithCause: Double = 6,
            nameMeanAct: Double = 3,
            nameMeanActCap: Double = 24,
            nameMeanActWindowDays: Int = 180,
            nameGuiltyVerdict: Double = 10,
            nameFameLevel: Double = 4,
            nameAlumnusVouch: Double = 3,
            vouchRapport: Double = 60,
            askDivisor: Double = 200,
            refuseAt: Double = 50,
            spotlightPerRung: Double = 0.25,
            launderDiscovery: Double = 0.035
        ) {
            self.boardOpenCase = boardOpenCase
            self.boardGuiltyVerdict = boardGuiltyVerdict
            self.boardBeefRound = boardBeefRound
            self.boardCancellation = boardCancellation
            self.boardCap = boardCap
            self.keyPersonClauseFactor = keyPersonClauseFactor
            self.nameNotorietyWeight = nameNotorietyWeight
            self.nameFiredWithCause = nameFiredWithCause
            self.nameMeanAct = nameMeanAct
            self.nameMeanActCap = nameMeanActCap
            self.nameMeanActWindowDays = nameMeanActWindowDays
            self.nameGuiltyVerdict = nameGuiltyVerdict
            self.nameFameLevel = nameFameLevel
            self.nameAlumnusVouch = nameAlumnusVouch
            self.vouchRapport = vouchRapport
            self.askDivisor = askDivisor
            self.refuseAt = refuseAt
            self.spotlightPerRung = spotlightPerRung
            self.launderDiscovery = launderDiscovery
        }

        public static let `default` = StandingRecordBalance()

        private enum CodingKeys: String, CodingKey {
            case boardOpenCase, boardGuiltyVerdict, boardBeefRound, boardCancellation
            case boardCap, keyPersonClauseFactor
            case nameNotorietyWeight, nameFiredWithCause, nameMeanAct, nameMeanActCap
            case nameMeanActWindowDays, nameGuiltyVerdict, nameFameLevel, nameAlumnusVouch
            case vouchRapport, askDivisor, refuseAt
            case spotlightPerRung, launderDiscovery
        }

        /// Decode-if-present on every key against the shipped default, so a
        /// `"standing"` block with a key missing still loads.
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let fallback = StandingRecordBalance()
            func double(_ key: CodingKeys, _ value: Double) throws -> Double {
                try container.decodeIfPresent(Double.self, forKey: key) ?? value
            }
            self.init(
                boardOpenCase: try double(.boardOpenCase, fallback.boardOpenCase),
                boardGuiltyVerdict: try double(.boardGuiltyVerdict, fallback.boardGuiltyVerdict),
                boardBeefRound: try double(.boardBeefRound, fallback.boardBeefRound),
                boardCancellation: try double(.boardCancellation, fallback.boardCancellation),
                boardCap: try double(.boardCap, fallback.boardCap),
                keyPersonClauseFactor: try double(
                    .keyPersonClauseFactor, fallback.keyPersonClauseFactor
                ),
                nameNotorietyWeight: try double(.nameNotorietyWeight, fallback.nameNotorietyWeight),
                nameFiredWithCause: try double(.nameFiredWithCause, fallback.nameFiredWithCause),
                nameMeanAct: try double(.nameMeanAct, fallback.nameMeanAct),
                nameMeanActCap: try double(.nameMeanActCap, fallback.nameMeanActCap),
                nameMeanActWindowDays: try container.decodeIfPresent(
                    Int.self, forKey: .nameMeanActWindowDays
                ) ?? fallback.nameMeanActWindowDays,
                nameGuiltyVerdict: try double(.nameGuiltyVerdict, fallback.nameGuiltyVerdict),
                nameFameLevel: try double(.nameFameLevel, fallback.nameFameLevel),
                nameAlumnusVouch: try double(.nameAlumnusVouch, fallback.nameAlumnusVouch),
                vouchRapport: try double(.vouchRapport, fallback.vouchRapport),
                askDivisor: try double(.askDivisor, fallback.askDivisor),
                refuseAt: try double(.refuseAt, fallback.refuseAt),
                spotlightPerRung: try double(.spotlightPerRung, fallback.spotlightPerRung),
                launderDiscovery: try double(.launderDiscovery, fallback.launderDiscovery)
            )
        }
    }
}
