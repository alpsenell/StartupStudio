import Foundation
import TycoonContent

// Iteration 12 — J3. Rivals follow the money, the price war gets an answer,
// and the copycat takes the card.
//
// **Identity at the default.** Three gates, none of which a bot opens:
//
// - *Rivals follow the money* waits for `RivalMarketState.noticed`, which
//   only `.noticeMarketOpened` sets, and the app sends that only when the
//   market board is opened. Until then the launch topic is the uniform
//   pick it always was, no studio moves into a boom or out of a crash, and
//   every rival product is typed the way it always was.
// - *Answer the price war* is three new actions. Unanswered, a war is
//   outlasted, which is what every war was.
// - *The copycat takes the card* reads `RivalProduct.copiedFeature`, which
//   only a placed feature board can write.
//
// `RivalMarketState` encodes only what is set, so a run that opens none of
// these doors writes the JSON it wrote before this file existed. Nothing
// here draws: the launch pick is the same single `worldRNG` word, mapped
// through weights instead of a modulo.

// MARK: - State

/// Why a studio moved.
public enum RivalMarketMoveKind: String, Codable, Equatable, Sendable {
    /// Added the topic to its focus the week it boomed.
    case boomEntry
    /// Dropped the topic after it sat under the crash line for a month.
    case crashExit
}

/// One studio moving into or out of a topic, as the market remembers it.
public struct RivalMarketMove: Codable, Equatable, Sendable {
    public var rivalID: UUID
    /// The studio's name that week, so the line survives a fold.
    public var rivalName: String
    public var topicID: String
    public var day: Int
    public var kind: RivalMarketMoveKind
    /// The topic's multiplier that week.
    public var multiplier: Double

    public init(
        rivalID: UUID, rivalName: String, topicID: String,
        day: Int, kind: RivalMarketMoveKind, multiplier: Double
    ) {
        self.rivalID = rivalID
        self.rivalName = rivalName
        self.topicID = topicID
        self.day = day
        self.kind = kind
        self.multiplier = multiplier
    }
}

/// The three answers to a price war.
public enum RivalMarketPriceWarAnswer: String, Codable, Equatable, Sendable, CaseIterable {
    /// Go budget for the war: the share penalty lifts, the rival bleeds
    /// and remembers it.
    case match
    /// Patch the product: if the patch lands inside the war, the war ends.
    case outship
    /// Take it. What every war was before this lane, and the default.
    case outlast

    public var displayName: String {
        switch self {
        case .match: "Match them"
        case .outship: "Out-ship them"
        case .outlast: "Outlast them"
        }
    }
}

/// A war the player answered, kept until the war is over.
public struct RivalMarketWarAnswer: Codable, Equatable, Sendable {
    public var rivalID: UUID
    public var topicID: String
    public var answer: RivalMarketPriceWarAnswer
    public var answeredDay: Int
    /// The war's last day, as the rival had it when the answer was given —
    /// which is what ties the answer to this war rather than the next one.
    public var untilDay: Int
    /// The product the answer was about.
    public var productID: UUID?
    /// Match: the tier the product was on before it went budget, restored
    /// when the war ends. `nil` when it was budget already.
    public var restoreTier: PriceTier?

    public init(
        rivalID: UUID, topicID: String, answer: RivalMarketPriceWarAnswer,
        answeredDay: Int, untilDay: Int, productID: UUID? = nil, restoreTier: PriceTier? = nil
    ) {
        self.rivalID = rivalID
        self.topicID = topicID
        self.answer = answer
        self.answeredDay = answeredDay
        self.untilDay = untilDay
        self.productID = productID
        self.restoreTier = restoreTier
    }
}

/// Everything J3 keeps. Encoded only when something is set.
public struct RivalMarketState: Codable, Equatable, Sendable {
    /// The market board has been opened. The gate for *rivals follow the
    /// money*; set once, by `.noticeMarketOpened`.
    public var noticed: Bool
    /// Boom entries and crash exits, oldest first, capped by
    /// `rivalMarket.moveLogCap`.
    public var moves: [RivalMarketMove]
    /// Answers to wars still running.
    public var answers: [RivalMarketWarAnswer]
    /// Studios fed false plans by W3's counterintelligence answer: their
    /// next clone lifts the player's worst card instead of the best.
    public var fedFalsePlans: [UUID]

    public init(
        noticed: Bool = false,
        moves: [RivalMarketMove] = [],
        answers: [RivalMarketWarAnswer] = [],
        fedFalsePlans: [UUID] = []
    ) {
        self.noticed = noticed
        self.moves = moves
        self.answers = answers
        self.fedFalsePlans = fedFalsePlans
    }

    public static let empty = RivalMarketState()

    /// The answer given to the war a rival is running now, if any.
    public func answer(to rival: Rival) -> RivalMarketWarAnswer? {
        guard let until = rival.priceWarUntilDay else { return nil }
        return answers.last { $0.rivalID == rival.id && $0.untilDay == until }
    }

    /// Whether a rival's current war has been matched — the one fact the
    /// share pass needs.
    public func isMatched(_ rival: Rival) -> Bool {
        answer(to: rival)?.answer == .match
    }

    /// The most recent move a studio made in a topic.
    public func latestMove(rivalID: UUID, topicID: String) -> RivalMarketMove? {
        moves.last { $0.rivalID == rivalID && $0.topicID == topicID }
    }

    private enum CodingKeys: String, CodingKey {
        case noticed, moves, answers, fedFalsePlans
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            noticed: try container.decodeIfPresent(Bool.self, forKey: .noticed) ?? false,
            moves: try container.decodeIfPresent([RivalMarketMove].self, forKey: .moves) ?? [],
            answers: try container.decodeIfPresent([RivalMarketWarAnswer].self, forKey: .answers) ?? [],
            fedFalsePlans: try container.decodeIfPresent([UUID].self, forKey: .fedFalsePlans) ?? []
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if noticed { try container.encode(noticed, forKey: .noticed) }
        if !moves.isEmpty { try container.encode(moves, forKey: .moves) }
        if !answers.isEmpty { try container.encode(answers, forKey: .answers) }
        if !fedFalsePlans.isEmpty { try container.encode(fedFalsePlans, forKey: .fedFalsePlans) }
    }
}

// MARK: - Refusals

/// Why an answer to a price war was refused. The sheet puts the sentence
/// under the button.
public enum RivalMarketPriceWarRefusal: String, Equatable, Sendable {
    case noWar
    case answered
    case windowClosed
    case nothingOnSale
    case noFreeSlot
    case cannotPatch

    public var reason: String {
        switch self {
        case .noWar: "Nobody is running a price war on you."
        case .answered: "You have already answered this one."
        case .windowClosed: "Too late to answer. You are outlasting it."
        case .nothingOnSale: "You have nothing on sale in that topic."
        case .noFreeSlot: "Every build slot is busy. A patch needs one."
        case .cannotPatch: "That product cannot take a patch right now."
        }
    }
}

// MARK: - Reads

/// A studio interested in a topic, and why.
public struct RivalMarketCircling: Equatable, Sendable, Identifiable {
    public enum Reason: String, Equatable, Sendable {
        /// Moved in on the boom.
        case boom
        /// A copycat, following the player.
        case copycat
        /// Won a category fight here.
        case lostFight
        /// It has always been one of theirs.
        case home
    }

    public var rivalID: UUID
    public var name: String
    public var reason: Reason
    /// When it moved in, for a boom entry.
    public var sinceDay: Int?
    /// Whether it already has something on sale here.
    public var isSelling: Bool

    public var id: UUID { rivalID }
}

public enum RivalMarket {
    /// Raised the first time a studio moves into a boom the player is
    /// selling in. `rivalmarket_` events read it.
    public static let companyFlag = "rivalmarket_company"
    /// Raised by the first matched price war.
    public static let matchedFlag = "rivalmarket_matched"
    /// Raised the first time a clone lifts a card off the player's board.
    public static let copiedFlag = "rivalmarket_copied"

    /// Days in a price war, from the tuning the war itself uses.
    static var warDays: Int { RivalDepthTuning.priceWarWeeks * GameState.daysPerWeek }

    // MARK: The launch pick

    /// A topic's pull on a launch: its multiplier to the balance's power.
    public static func weight(multiplier: Double, exponent: Double) -> Double {
        pow(max(0.01, multiplier), exponent)
    }

    /// The type a rival ships into a topic once it reads the market: the
    /// type the topic suits best, catalog order breaking ties. `nil` for a
    /// topic the catalog does not know.
    public static func productTypeID(for topicID: String, content: ContentCatalog) -> String? {
        guard let topic = content.topic(topicID) else { return nil }
        var best: (id: String, fit: Double)?
        for type in content.productTypes {
            let fit = topic.fitByType[type.id] ?? 1
            if best == nil || fit > best!.fit { best = (type.id, fit) }
        }
        return best?.id
    }

    // MARK: Who is circling

    /// Every studio with this topic in its focus, the ones not yet selling
    /// first, then by name. Empty until the market has been opened: the
    /// line is F3's, and F3 is off until then.
    public static func circling(topicID: String, state: GameState) -> [RivalMarketCircling] {
        guard state.rivalMarket.noticed else { return [] }
        let day = state.day
        return state.rivals.rivals
            .filter { $0.focusTopicIDs.contains(topicID) }
            .map { rival in
                let move = state.rivalMarket.latestMove(rivalID: rival.id, topicID: topicID)
                let reason: RivalMarketCircling.Reason = if move?.kind == .boomEntry {
                    .boom
                } else if rival.personality == .copycat, rival.focusTopicIDs.first != topicID {
                    .copycat
                } else if rival.focusTopicIDs.first != topicID {
                    .lostFight
                } else {
                    .home
                }
                return RivalMarketCircling(
                    rivalID: rival.id,
                    name: rival.name,
                    reason: reason,
                    sinceDay: move?.kind == .boomEntry ? move?.day : nil,
                    isSelling: rival.bestProduct(in: topicID, on: day) != nil
                )
            }
            .sorted { lhs, rhs in
                if lhs.isSelling != rhs.isSelling { return !lhs.isSelling }
                return lhs.name < rhs.name
            }
    }

    /// Whether a studio has moved into this topic on a boom and not yet
    /// shipped there: the siege marker on the map.
    public static func isBesieged(topicID: String, state: GameState) -> Bool {
        circling(topicID: topicID, state: state).contains { $0.reason == .boom && !$0.isSelling }
    }

    // MARK: The copied card

    /// The studio whose live clone in this topic lifted a card of this
    /// name, if one has. First by id, so the answer replays.
    public static func copiedBy(cardName: String, topicID: String, state: GameState) -> Rival? {
        let day = state.day
        return state.rivals.rivals
            .filter { rival in
                rival.competingProducts(on: day).contains {
                    $0.topicID == topicID && $0.copiedFeature == cardName
                }
            }
            .min { $0.id.uuidString < $1.id.uuidString }
    }

    // MARK: The price war

    /// The day a rival's current war started.
    public static func warStartDay(_ rival: Rival) -> Int? {
        rival.priceWarUntilDay.map { $0 - warDays }
    }

    /// The last day a rival's current war can be answered.
    public static func answerDeadline(_ rival: Rival, balance: BalanceConfig) -> Int? {
        warStartDay(rival).map { $0 + max(0, balance.rivalMarket.answerWindowDays) - 1 }
    }

    /// The war waiting for an answer — the sheet's question. Oldest war
    /// first; `nil` once every war is answered or past its window.
    public static func pendingPriceWar(state: GameState, balance: BalanceConfig) -> Rival? {
        let day = state.day
        return state.rivals.rivals
            .filter { rival in
                guard rival.isInPriceWar(on: day), rival.priceWarTopicID != nil,
                      state.rivalMarket.answer(to: rival) == nil,
                      let deadline = answerDeadline(rival, balance: balance)
                else { return false }
                return day <= deadline
            }
            .min { ($0.priceWarUntilDay ?? 0, $0.id.uuidString) < ($1.priceWarUntilDay ?? 0, $1.id.uuidString) }
    }

    /// Why `.answerPriceWar` would be refused, without sending it: a dry
    /// run of the real handler on a copy, so the sentence under the button
    /// can never disagree with the reducer. `nil` means it would land.
    public static func refusal(
        answering answer: RivalMarketPriceWarAnswer,
        rivalID: UUID,
        state: GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> RivalMarketPriceWarRefusal? {
        var copy = state
        return RivalSystem.rivalMarketAnswer(
            rivalID: rivalID, answer: answer, state: &copy, balance: balance, content: content
        ).refusal
    }

    /// The product a war is being fought over: the player's best live one
    /// in the topic, the one the share pass scores.
    public static func warProduct(in topicID: String, state: GameState) -> Product? {
        RivalSystem.playerBestProduct(in: topicID, state).flatMap { state.product(id: $0.id) }
    }
}
