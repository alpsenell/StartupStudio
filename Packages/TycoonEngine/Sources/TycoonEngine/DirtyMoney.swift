import Foundation

// Iteration 11, wave two — W1 owns this file. The money that answers when
// nobody else does: the three backers, the cheque, the strings with their
// clocks, the compliance record and the heat.
//
// **Identity at the default.** `GameState.dirtyMoney` is `.empty` until
// the player opens the Business tab's finances (`.noticeFinancesOpened`,
// the `noticeProductsOpened` pattern), it is encoded only while it is
// non-empty, and `DirtyMoneySystem` returns on its first line while it is
// empty. No pacing bot opens a screen, so no bot is ever offered a cheque,
// and every fixture written before this lane existed replays byte for
// byte.
//
// **Draws.** `socialRNG` only, and only once an offer is live or a cheque
// has been taken: one word a week for the offer roll, one to pick the
// backer, one a week for the reprisal roll and one to pick which reprisal.
// `rng` and `worldRNG` are never touched.
//
// Types here are prefixed `DirtyMoney…` (rule 8).

// MARK: - The three backers

/// Who turns up when the bank has stopped answering.
///
/// Raw values are written into saves (`DirtyMoneyState.backer`), so they
/// are stable. What each one pays, and what each one wants, is in
/// `BalanceConfig.DirtyMoneyBalance`.
public enum DirtyMoneyBacker: String, Codable, Equatable, Sendable, CaseIterable {
    /// An oligarch's family office. The largest cheque and the longest
    /// strings: a consultant you have never met, and a market they choose.
    case familyOffice
    /// A fund that is a front. A quarterly invoice to a company that does
    /// not exist, and then a nephew.
    case theFront
    /// A man who found you at demo day. Small money, weekly vig, and a
    /// visit when a payment is late.
    case theShark

    public var displayName: String {
        switch self {
        case .familyOffice: "Kasimov Family Office"
        case .theFront: "Meridian Partners"
        case .theShark: "Denny"
        }
    }

    /// How they describe themselves, which is not how the record will.
    public var blurb: String {
        switch self {
        case .familyOffice:
            "Single-family capital. Patient, discreet, and extremely interested in you."
        case .theFront:
            "A fund with an address in a building with no other tenants."
        case .theShark:
            "He remembers your demo. He remembers everybody's demo."
        }
    }

    /// The line on the offer sheet, under the cheque.
    public var pitch: String {
        switch self {
        case .familyOffice:
            "No board seat, no diligence, no data room. They would only like to be helpful."
        case .theFront:
            "The money is here tomorrow. Nobody signs anything that has your name on it twice."
        case .theShark:
            "Cash on Friday. The interest is weekly and he says it like it's a subscription."
        }
    }

    /// What the founder is agreeing to, printed on the button, so rule 7
    /// holds before the cheque is banked.
    public var stringsLine: String {
        switch self {
        case .familyOffice:
            "A consultant on the payroll from month two, and a market of their choosing by month six."
        case .theFront:
            "An invoice a quarter to a company that does not exist. Then a nephew."
        case .theShark:
            "The vig, every week, out of the company account. He counts it himself."
        }
    }

    public var symbol: String {
        switch self {
        case .familyOffice: "building.2.crop.circle.fill"
        case .theFront: "shippingbox.fill"
        case .theShark: "figure.stand"
        }
    }

    /// Who the phone says it is from.
    public var messageName: String {
        switch self {
        case .familyOffice: "The family office"
        case .theFront: "Meridian"
        case .theShark: "Denny"
        }
    }
}

// MARK: - The strings

/// One string, with a clock on it.
public enum DirtyMoneyDemandKind: String, Codable, Equatable, Sendable, CaseIterable {
    /// The family office would like somebody on the payroll. He will not
    /// be at the standup.
    case consultant
    /// The family office has chosen a market for you.
    case theirMarket
    /// The front's quarterly invoice, to a company with a website and a
    /// PO box.
    case invoice
    /// The front's nephew. He is keen.
    case nephew
    /// The shark's payment is late and he has come to say so in person.
    case lateVisit

    public var title: String {
        switch self {
        case .consultant: "A consultant"
        case .theirMarket: "A market of their choosing"
        case .invoice: "An invoice"
        case .nephew: "The nephew"
        case .lateVisit: "A visit"
        }
    }

    /// The paragraph on the sheet.
    public var body: String {
        switch self {
        case .consultant:
            "They would like Anton on the payroll from Monday. Anton's expertise is not specified and neither is Anton. He will not need a desk."
        case .theirMarket:
            "They have chosen a market for your next product. They are not asking whether it is a good market. They are telling you which one it is."
        case .invoice:
            "An invoice has arrived from a consultancy you have never used, for work nobody can describe, on headed paper that is genuinely very nice."
        case .nephew:
            "His nephew is finishing something, or has finished something, and would suit your team. There is no CV attached and there is not going to be one."
        case .lateVisit:
            "Denny is in reception. He has brought somebody who does not speak and has not sat down."
        }
    }

    /// What complying looks like on the button.
    public var complyLabel: String {
        switch self {
        case .consultant: "Put him on the payroll"
        case .theirMarket: "Build for their market"
        case .invoice: "Pay the invoice"
        case .nephew: "Hire the nephew"
        case .lateVisit: "Pay him now"
        }
    }

    public var symbol: String {
        switch self {
        case .consultant: "person.crop.square.fill"
        case .theirMarket: "map.fill"
        case .invoice: "doc.text.fill"
        case .nephew: "person.fill.badge.plus"
        case .lateVisit: "bell.badge.fill"
        }
    }

    /// A demand that moves money is laundering the moment it is paid; the
    /// rest are favours, which the record does not know how to price.
    public var isPayment: Bool {
        self == .invoice || self == .lateVisit
    }
}

/// What the founder said to a string.
public enum DirtyMoneyAnswer: String, Codable, Equatable, Sendable, CaseIterable {
    /// Do it, and pay what it costs.
    case comply
    /// Ask for a fortnight. Once per string, and they notice.
    case stall
    /// No. They also notice this.
    case refuse

    public var displayName: String {
        switch self {
        case .comply: "Comply"
        case .stall: "Stall"
        case .refuse: "Refuse"
        }
    }

    public var symbol: String {
        switch self {
        case .comply: "checkmark.circle.fill"
        case .stall: "clock.badge.questionmark.fill"
        case .refuse: "xmark.octagon.fill"
        }
    }
}

/// A string that has been pulled: what they want, by when, and what was
/// said.
public struct DirtyMoneyDemand: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var kind: DirtyMoneyDemandKind
    public var raisedDay: Int
    public var dueDay: Int
    /// What complying costs in dollars, where it costs dollars. Zero for
    /// the favours.
    public var amount: Int
    /// The topic id the family office named, for `theirMarket`.
    public var topicID: String?
    /// Set once the founder answered, or the deadline answered for them.
    public var answer: DirtyMoneyAnswer?
    public var answeredDay: Int?
    /// A string can be stalled once.
    public var stalled: Bool

    public init(
        id: String,
        kind: DirtyMoneyDemandKind,
        raisedDay: Int,
        dueDay: Int,
        amount: Int = 0,
        topicID: String? = nil,
        answer: DirtyMoneyAnswer? = nil,
        answeredDay: Int? = nil,
        stalled: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.raisedDay = raisedDay
        self.dueDay = dueDay
        self.amount = amount
        self.topicID = topicID
        self.answer = answer
        self.answeredDay = answeredDay
        self.stalled = stalled
    }

    /// Still waiting on the founder.
    public var isOpen: Bool { answer == nil }

    /// Days left, never below zero.
    public func daysLeft(from day: Int) -> Int { max(0, dueDay - day) }

    private enum CodingKeys: String, CodingKey {
        case id, kind, raisedDay, dueDay, amount, topicID, answer, answeredDay, stalled
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try c.decode(String.self, forKey: .id),
            kind: try c.decode(DirtyMoneyDemandKind.self, forKey: .kind),
            raisedDay: try c.decode(Int.self, forKey: .raisedDay),
            dueDay: try c.decode(Int.self, forKey: .dueDay),
            amount: try c.decodeIfPresent(Int.self, forKey: .amount) ?? 0,
            topicID: try c.decodeIfPresent(String.self, forKey: .topicID),
            answer: try c.decodeIfPresent(DirtyMoneyAnswer.self, forKey: .answer),
            answeredDay: try c.decodeIfPresent(Int.self, forKey: .answeredDay),
            stalled: try c.decodeIfPresent(Bool.self, forKey: .stalled) ?? false
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(kind, forKey: .kind)
        try c.encode(raisedDay, forKey: .raisedDay)
        try c.encode(dueDay, forKey: .dueDay)
        if amount != 0 { try c.encode(amount, forKey: .amount) }
        try c.encodeIfPresent(topicID, forKey: .topicID)
        try c.encodeIfPresent(answer, forKey: .answer)
        try c.encodeIfPresent(answeredDay, forKey: .answeredDay)
        if stalled { try c.encode(stalled, forKey: .stalled) }
    }
}

// MARK: - The passengers

/// Somebody the backer put on the payroll. Not an `Employee`: they do no
/// work, hold no desk and appear in no org chart, which is the joke and
/// also the reason they are cheap to carry.
public struct DirtyMoneyPassenger: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var title: String
    public var weeklyCost: Int
    public var sinceDay: Int

    public init(id: String, name: String, title: String, weeklyCost: Int, sinceDay: Int) {
        self.id = id
        self.name = name
        self.title = title
        self.weeklyCost = weeklyCost
        self.sinceDay = sinceDay
    }
}

// MARK: - What the heat pays out as

/// What happens to a founder who says no, or says nothing.
public enum DirtyMoneyReprisal: String, Codable, Equatable, Sendable, CaseIterable {
    /// The office window, on a Tuesday, from the outside.
    case window
    /// The car is not on the drive.
    case car
    /// A friend is asked about you, and stops answering.
    case friend
    /// A rival's week improves for reasons nobody explains.
    case rival

    public var line: String {
        switch self {
        case .window: "The office window came in overnight. Nobody saw anything and nobody was going to."
        case .car: "The car is not where you left it, and the space has been swept."
        case .friend: "Somebody went to see a friend of yours and asked about you for an hour."
        case .rival: "A rival closed a round this week from a fund with the same address as yours."
        }
    }

    public var symbol: String {
        switch self {
        case .window: "windshield.front.and.wiper.exclamationmark"
        case .car: "car.fill"
        case .friend: "person.2.slash.fill"
        case .rival: "flag.2.crossed.fill"
        }
    }
}

// MARK: - The way out

/// How the relationship ended.
public enum DirtyMoneyExit: String, Codable, Equatable, Sendable, CaseIterable {
    /// Paid off at a multiple of the cheque.
    case paidOff
    /// Turned witness: the laundering went to a court with the founder's
    /// own signature on the statement.
    case turnedWitness
    /// Sold them the company.
    case soldUp

    public var displayName: String {
        switch self {
        case .paidOff: "Paid off"
        case .turnedWitness: "Turned witness"
        case .soldUp: "Sold up"
        }
    }
}

// MARK: - The state

public struct DirtyMoneyState: Codable, Equatable, Sendable {
    /// The player has looked at the company's finances. Nothing in this
    /// lane happens until they have; see the note at the top of the file.
    public var noticed: Bool
    /// The backer whose money is in the account. `nil` until a cheque is
    /// taken, and `nil` again once it is answered for.
    public var backer: String?
    public var takenDay: Int?
    /// 0…100. How annoyed they are.
    public var heat: Double

    /// An offer on the table, and the day it goes away.
    public var offeredBacker: String?
    public var offeredCheque: Int
    public var offerRespondByDay: Int?
    /// Backers already offered, so the same one is not offered twice.
    public var offeredAlready: [String]

    /// What was banked, so the payoff and the sale have a number.
    public var cheque: Int
    /// The strings, oldest first. Answered ones stay as the record.
    public var demands: [DirtyMoneyDemand]
    /// People on the payroll who are not on the team.
    public var passengers: [DirtyMoneyPassenger]
    /// The market they named, once they named it.
    public var namedTopicID: String?
    /// Everything paid through them, which is the number a court asks for.
    public var laundered: Int
    public var complied: Int
    public var refused: Int
    /// The last day the weekly pass ran, so a save loaded mid-week does
    /// not roll twice.
    public var lastSweepDay: Int?
    /// The last day a demand was raised, so two do not land at once.
    public var lastDemandDay: Int?
    /// The last day the vig was taken.
    public var lastVigDay: Int?
    /// The last day the heat paid out as something happening, so a bad
    /// month is not a bad week.
    public var lastReprisalDay: Int?
    /// How it ended, and when.
    public var exit: DirtyMoneyExit?
    public var exitDay: Int?

    public init(
        noticed: Bool = false,
        backer: String? = nil,
        takenDay: Int? = nil,
        heat: Double = 0,
        offeredBacker: String? = nil,
        offeredCheque: Int = 0,
        offerRespondByDay: Int? = nil,
        offeredAlready: [String] = [],
        cheque: Int = 0,
        demands: [DirtyMoneyDemand] = [],
        passengers: [DirtyMoneyPassenger] = [],
        namedTopicID: String? = nil,
        laundered: Int = 0,
        complied: Int = 0,
        refused: Int = 0,
        lastSweepDay: Int? = nil,
        lastDemandDay: Int? = nil,
        lastVigDay: Int? = nil,
        lastReprisalDay: Int? = nil,
        exit: DirtyMoneyExit? = nil,
        exitDay: Int? = nil
    ) {
        self.noticed = noticed
        self.backer = backer
        self.takenDay = takenDay
        self.heat = heat
        self.offeredBacker = offeredBacker
        self.offeredCheque = offeredCheque
        self.offerRespondByDay = offerRespondByDay
        self.offeredAlready = offeredAlready
        self.cheque = cheque
        self.demands = demands
        self.passengers = passengers
        self.namedTopicID = namedTopicID
        self.laundered = laundered
        self.complied = complied
        self.refused = refused
        self.lastSweepDay = lastSweepDay
        self.lastDemandDay = lastDemandDay
        self.lastVigDay = lastVigDay
        self.lastReprisalDay = lastReprisalDay
        self.exit = exit
        self.exitDay = exitDay
    }

    public static let empty = DirtyMoneyState()

    /// Answered strings kept for the record.
    static let maxDemands = 20

    /// The backer as the enum, when there is one.
    public var backerKind: DirtyMoneyBacker? { backer.flatMap(DirtyMoneyBacker.init(rawValue:)) }

    /// The offer as the enum, when one is on the table.
    public var offeredKind: DirtyMoneyBacker? {
        offeredBacker.flatMap(DirtyMoneyBacker.init(rawValue:))
    }

    /// The string waiting on an answer, if any. At most one at a time.
    public var openDemand: DirtyMoneyDemand? { demands.first { $0.isOpen } }

    /// Whether an offer is live on this day.
    public func hasOffer(on day: Int) -> Bool {
        guard offeredBacker != nil, let by = offerRespondByDay else { return false }
        return day <= by
    }

    /// Somebody's money is in the account and has not been answered for.
    public var isBacked: Bool { backer != nil }

    /// The weekly cost of everybody the backer put on the payroll.
    public var passengerWeeklyCost: Int { passengers.reduce(0) { $0 + $1.weeklyCost } }

    private enum CodingKeys: String, CodingKey {
        case noticed, backer, takenDay, heat
        case offeredBacker, offeredCheque, offerRespondByDay, offeredAlready
        case cheque, demands, passengers, namedTopicID, laundered, complied, refused
        case lastSweepDay, lastDemandDay, lastVigDay, lastReprisalDay, exit, exitDay
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            noticed: try c.decodeIfPresent(Bool.self, forKey: .noticed) ?? false,
            backer: try c.decodeIfPresent(String.self, forKey: .backer),
            takenDay: try c.decodeIfPresent(Int.self, forKey: .takenDay),
            heat: try c.decodeIfPresent(Double.self, forKey: .heat) ?? 0,
            offeredBacker: try c.decodeIfPresent(String.self, forKey: .offeredBacker),
            offeredCheque: try c.decodeIfPresent(Int.self, forKey: .offeredCheque) ?? 0,
            offerRespondByDay: try c.decodeIfPresent(Int.self, forKey: .offerRespondByDay),
            offeredAlready: try c.decodeIfPresent([String].self, forKey: .offeredAlready) ?? [],
            cheque: try c.decodeIfPresent(Int.self, forKey: .cheque) ?? 0,
            demands: try c.decodeIfPresent([DirtyMoneyDemand].self, forKey: .demands) ?? [],
            passengers: try c.decodeIfPresent([DirtyMoneyPassenger].self, forKey: .passengers) ?? [],
            namedTopicID: try c.decodeIfPresent(String.self, forKey: .namedTopicID),
            laundered: try c.decodeIfPresent(Int.self, forKey: .laundered) ?? 0,
            complied: try c.decodeIfPresent(Int.self, forKey: .complied) ?? 0,
            refused: try c.decodeIfPresent(Int.self, forKey: .refused) ?? 0,
            lastSweepDay: try c.decodeIfPresent(Int.self, forKey: .lastSweepDay),
            lastDemandDay: try c.decodeIfPresent(Int.self, forKey: .lastDemandDay),
            lastVigDay: try c.decodeIfPresent(Int.self, forKey: .lastVigDay),
            lastReprisalDay: try c.decodeIfPresent(Int.self, forKey: .lastReprisalDay),
            exit: try c.decodeIfPresent(DirtyMoneyExit.self, forKey: .exit),
            exitDay: try c.decodeIfPresent(Int.self, forKey: .exitDay)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        if noticed { try c.encode(noticed, forKey: .noticed) }
        try c.encodeIfPresent(backer, forKey: .backer)
        try c.encodeIfPresent(takenDay, forKey: .takenDay)
        if heat != 0 { try c.encode(heat, forKey: .heat) }
        try c.encodeIfPresent(offeredBacker, forKey: .offeredBacker)
        if offeredCheque != 0 { try c.encode(offeredCheque, forKey: .offeredCheque) }
        try c.encodeIfPresent(offerRespondByDay, forKey: .offerRespondByDay)
        if !offeredAlready.isEmpty { try c.encode(offeredAlready.sorted(), forKey: .offeredAlready) }
        if cheque != 0 { try c.encode(cheque, forKey: .cheque) }
        if !demands.isEmpty { try c.encode(demands, forKey: .demands) }
        if !passengers.isEmpty { try c.encode(passengers, forKey: .passengers) }
        try c.encodeIfPresent(namedTopicID, forKey: .namedTopicID)
        if laundered != 0 { try c.encode(laundered, forKey: .laundered) }
        if complied != 0 { try c.encode(complied, forKey: .complied) }
        if refused != 0 { try c.encode(refused, forKey: .refused) }
        try c.encodeIfPresent(lastSweepDay, forKey: .lastSweepDay)
        try c.encodeIfPresent(lastDemandDay, forKey: .lastDemandDay)
        try c.encodeIfPresent(lastVigDay, forKey: .lastVigDay)
        try c.encodeIfPresent(lastReprisalDay, forKey: .lastReprisalDay)
        try c.encodeIfPresent(exit, forKey: .exit)
        try c.encodeIfPresent(exitDay, forKey: .exitDay)
    }
}

// MARK: - Why an action was refused

/// Rule 7: a refused action says why, in the founder's words.
public enum DirtyMoneyRefusal: String, Sendable, Equatable, CaseIterable {
    case noOffer
    case alreadyBacked
    case noBacker
    case nothingToAnswer
    case alreadyStalled
    case cannotAfford
    case nothingToConfess
    case away

    public var sentence: String {
        switch self {
        case .noOffer: "Nobody is offering you anything today."
        case .alreadyBacked: "You already have somebody's money. One is plenty."
        case .noBacker: "There is nobody to do that to."
        case .nothingToAnswer: "Nothing is being asked of you this week."
        case .alreadyStalled: "You've already asked them to wait once. There isn't a second time."
        case .cannotAfford: "You cannot cover it, and they do not take instalments."
        case .nothingToConfess: "There is nothing on the record to turn in yet."
        case .away: "You're not at your desk, and this is not a phone call."
        }
    }
}

// MARK: - The arithmetic

/// The lane's pure half: what a cheque is worth, what a string costs, what
/// an answer does to the heat, and what the way out is priced at.
///
/// Nothing here mutates, draws or reads a clock, so the app can put the
/// same number on the button that the engine is about to write.
public enum DirtyMoney {

    /// The cheque a backer writes. Scaled a little by how big the company
    /// already is: they are not writing a seed cheque to a campus.
    public static func cheque(
        _ backer: DirtyMoneyBacker,
        payroll: Int,
        balance: BalanceConfig.DirtyMoneyBalance
    ) -> Int {
        let base = balance.cheque(for: backer)
        let scale = 1 + min(
            balance.chequePayrollCap,
            Double(max(0, payroll)) / max(1, Double(balance.chequePayrollDivisor))
        )
        return Int((Double(base) * scale).rounded() / 1000) * 1000
    }

    /// What complying with a string costs, in dollars.
    public static func demandAmount(
        _ kind: DirtyMoneyDemandKind,
        cheque: Int,
        balance: BalanceConfig.DirtyMoneyBalance
    ) -> Int {
        switch kind {
        case .invoice:
            max(balance.invoiceFloor, Int((Double(cheque) * balance.invoiceFractionOfCheque).rounded()))
        case .lateVisit:
            max(balance.vigFloor, Int((Double(cheque) * balance.vigFractionOfCheque * 3).rounded()))
        case .consultant, .nephew, .theirMarket:
            0
        }
    }

    /// The weekly vig: what the shark takes for as long as the money is
    /// theirs.
    public static func vig(cheque: Int, balance: BalanceConfig.DirtyMoneyBalance) -> Int {
        max(balance.vigFloor, Int((Double(cheque) * balance.vigFractionOfCheque).rounded()))
    }

    /// The weekly cost of a passenger a string put on the payroll.
    public static func passengerCost(
        _ kind: DirtyMoneyDemandKind,
        cheque: Int,
        balance: BalanceConfig.DirtyMoneyBalance
    ) -> Int {
        let fraction = kind == .consultant
            ? balance.consultantFractionOfCheque
            : balance.nephewFractionOfCheque
        return max(balance.passengerFloor, Int((Double(cheque) * fraction).rounded()))
    }

    /// What an answer does to the heat. Complying cools it a little;
    /// stalling warms it; refusing warms it a lot.
    public static func heatDelta(
        _ answer: DirtyMoneyAnswer,
        kind: DirtyMoneyDemandKind,
        balance: BalanceConfig.DirtyMoneyBalance
    ) -> Double {
        let weight = kind.isPayment ? balance.paymentHeatWeight : 1
        switch answer {
        case .comply: return -balance.complyHeatRelief
        case .stall: return balance.stallHeat * weight
        case .refuse: return balance.refuseHeat * weight
        }
    }

    /// The chance, on a weekly roll, that the heat pays out as something
    /// happening. Zero at zero heat, so a compliant founder never rolls.
    public static func reprisalChance(
        heat: Double,
        balance: BalanceConfig.DirtyMoneyBalance
    ) -> Double {
        guard heat > balance.reprisalHeatFloor else { return 0 }
        let over = (heat - balance.reprisalHeatFloor) / max(1, 100 - balance.reprisalHeatFloor)
        return min(balance.reprisalCeiling, over * balance.reprisalFactor)
    }

    /// What it costs to be rid of them: the cheque, a multiple, and a
    /// surcharge for every degree of heat.
    public static func payoffPrice(
        cheque: Int,
        heat: Double,
        balance: BalanceConfig.DirtyMoneyBalance
    ) -> Int {
        let base = Double(cheque) * balance.payoffMultiple
        return Int((base * (1 + heat / 100 * balance.payoffHeatSurcharge)).rounded())
    }

    /// What they will pay for the whole company, which is less than it is
    /// worth and more than they have offered anybody else.
    public static func sellUpPrice(
        cheque: Int,
        valuation: Int,
        balance: BalanceConfig.DirtyMoneyBalance
    ) -> Int {
        max(cheque, Int((Double(valuation) * balance.sellUpValuationFraction).rounded()))
    }

    /// How hot it is, in one word.
    public static func heatLabel(_ heat: Double) -> String {
        switch heat {
        case ..<1: "They are happy with you"
        case ..<20: "Nothing has been said"
        case ..<45: "Somebody mentioned it twice"
        case ..<70: "They have stopped being pleasant"
        default: "They have decided something"
        }
    }

    /// The line on the offer sheet that says what the money is for.
    public static func offerLine(_ backer: DirtyMoneyBacker, cheque: Int) -> String {
        switch backer {
        case .familyOffice:
            "\(cheque.dirtyMoneyFigure), wired Thursday, against no equity anybody will write down."
        case .theFront:
            "\(cheque.dirtyMoneyFigure), in three transfers from three places, by the end of the week."
        case .theShark:
            "\(cheque.dirtyMoneyFigure), in a bag, today, and the week starts on Friday."
        }
    }

    /// What the ledger calls the cheque. A court will read this line.
    public static func ledgerLabel(_ backer: DirtyMoneyBacker) -> String {
        switch backer {
        case .familyOffice: "Strategic advance — Kasimov Family Office"
        case .theFront: "Consultancy prepayment — Meridian Partners"
        case .theShark: "Short-term facility"
        }
    }

    /// The one line the founder's own record keeps about a payment made
    /// through them.
    public static func launderNote(_ amount: Int, backer: DirtyMoneyBacker) -> String {
        "\(amount.dirtyMoneyFigure) went out through \(backer.displayName) and came back clean."
    }
}

// A money formatter for the engine's own copy, matching `Int.crimeMoney`
// in `Crime.swift`. (The app's `Int.money` lives in the app target.)
extension Int {
    var dirtyMoneyFigure: String { crimeMoney }
}
