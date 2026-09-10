import SwiftUI
import TycoonContent
import TycoonEngine

/// The Investors segment of the Business tab: the term sheet on the table,
/// the cap table, the board room, founder net worth, and the IPO desk.
struct InvestorsView: View {
    let engine: GameEngine

    @State private var confirmingIPO = false
    /// The round the founder is about to buy back, while the confirm is up.
    @State private var buyingBack: RaisedRound?

    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// See `GameShell.shared`: read optionally, because SwiftUI updates
    /// this property for presented content before the environment is
    /// installed and the non-optional form traps there.
    private var shell: GameShell { injectedShell ?? .shared }

    private var investors: InvestorState { engine.state.investors }
    // MARK: J2 (record)
    /// DEBUG screenshot pass only: the board card lifted onto a sheet.
    @State private var standingLiftsBoard = false
    // MARK: end J2

    var body: some View {
        BusinessSectionHeader(title: "Cap table", systemImage: "chart.pie.fill")

        if let offer = investors.pendingOffer {
            TermSheetCard(engine: engine, offer: offer)
        }

        // MARK: Iteration 11, wave two — W1 (dirty money)
        // The other money sits where money is asked for: a founder who
        // has just turned a term sheet down, or had none to turn down, is
        // looking at this page when the other phone rings.
        DirtyMoneyApproachNote(engine: engine)
        // MARK: end of Iteration 11, wave two — W1

        netWorthCard

        if investors.rounds.isEmpty {
            // `investorHint` is already the specific reason nobody has
            // called, so it goes on the hint line and the headline stays
            // the plain fact.
            EmptyStateCard(
                message: "You haven't raised.",
                systemImage: "chart.pie",
                hint: investorHint,
                tint: Theme.accent
            )
        } else {
            roundsCard
        }

        // An acquirer on an earn-out sits in the room like any seated round.
        if investors.hasBoard || investors.earnOut != nil {
            BusinessSectionHeader(title: "The board", systemImage: "person.3.fill")
            boardCard
                // MARK: J2 (record)
                // DEBUG: `-autoBoardReview case` lifts the card where a
                // camera can see it; nothing in the game presents this.
                .sheet(isPresented: $standingLiftsBoard) {
                    ScrollView { boardCard.padding(Theme.Spacing.lg) }
                        .background(Theme.screenBackground)
                }
                .task {
                    guard DebugLaunch.standingLiftsBoardCard else { return }
                    try? await Task.sleep(for: .seconds(4))
                    standingLiftsBoard = true
                }
                // MARK: end J2
        }

        BusinessSectionHeader(title: "Going public", systemImage: "bell.fill")
        ipoCard

        // WS-G: the other ending, with the same gate rows.
        BusinessSectionHeader(title: "Still yours", systemImage: "flag.checkered")
        IndependenceCard(engine: engine)
    }

    /// Why nobody has called yet, in the founder's terms.
    private var investorHint: String {
        let config = engine.balance.investors
        if engine.state.company.reputation < config.minReputation {
            return "Nobody has heard of you yet. Ship something people talk about "
                + "(reputation \(Int(engine.state.company.reputation.rounded())) of "
                + "\(Int(config.minReputation)) before anyone returns a call)."
        }
        if engine.state.day < config.earliestOfferDay {
            return "Too early. Investors want to see a company survive a few months first."
        }
        return "You own all of it. Term sheets arrive on their own once the "
            + "numbers are worth a meeting."
    }

    // MARK: - Net worth

    private var netWorthCard: some View {
        let balance = engine.balance
        let netWorth = engine.state.founderNetWorth(balance: balance)
        let valuation = engine.state.companyValuation(balance: balance)
        let equity = investors.equityRemaining

        return CardView("Your stake", systemImage: "person.crop.square.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    Text(netWorth.money)
                        .font(Theme.Typography.number(.title2, weight: .bold))
                        .contentTransition(.numericText())
                        .animation(Theme.Motion.valueChange, value: netWorth)
                    Text("net worth")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                EquityBar(founderShare: equity)

                VStack(alignment: .leading, spacing: 2) {
                    detailRow("You own", "\(equity.oneDecimal)%")
                    detailRow("Company valued at", valuation.money)
                    detailRow("In your wallet", engine.state.life.wallet.money)
                    if investors.totalRaised > 0 {
                        detailRow("Raised to date", investors.totalRaised.money)
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(
                "Founder net worth \(netWorth.money). You own \(equity.oneDecimal) percent "
                    + "of a company valued at \(valuation.money)."
            )
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(Theme.Typography.number(.caption))
        }
    }

    // MARK: - Rounds

    private var roundsCard: some View {
        CardView("Rounds raised", systemImage: "signature") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                ForEach(investors.rounds) { round in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(round.investorName)
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            if round.takesBoardSeat {
                                Text("BOARD")
                                    .font(.caption2.weight(.bold))
                                    .kerning(0.5)
                                    .foregroundStyle(Theme.warning)
                                    .padding(.horizontal, Theme.Spacing.xs + 2)
                                    .padding(.vertical, 2)
                                    .background(Theme.chipBackground, in: Capsule())
                            }
                            // MARK: K4 (deals and exits)
                            if round.isDealPaper {
                                Text("PAPER")
                                    .font(.caption2.weight(.bold))
                                    .kerning(0.5)
                                    .foregroundStyle(Theme.accent)
                                    .padding(.horizontal, Theme.Spacing.xs + 2)
                                    .padding(.vertical, 2)
                                    .background(Theme.chipBackground, in: Capsule())
                            }
                            // MARK: end K4
                            Spacer()
                            Text(round.amount.money)
                                .font(Theme.Typography.number(.subheadline))
                        }
                        Text("\(round.equity.oneDecimal)% at a \(round.valuation.money) valuation · day \(round.day)")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        // MARK: K4 (deals and exits)
                        if round.isDealPaper {
                            Text("Paid for their studio in stock, not cash · expects a ship every quarter")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        // MARK: end K4
                        buybackButton(round)
                    }
                    .accessibilityElement(children: .contain)
                }
            }
        }
        // The confirm carries the money line the decision sheet draws, so
        // a buyback reads like every other spend of the company's cash.
        .confirmationDialog(
            "Buy out \(buyingBack?.investorName ?? "the round")?",
            isPresented: Binding(
                get: { buyingBack != nil },
                set: { if !$0 { buyingBack = nil } }
            ),
            titleVisibility: .visible,
            presenting: buyingBack
        ) { round in
            let price = engine.state.buybackPrice(for: round, balance: engine.balance)
            Button("Pay \(price.money) and take back \(round.equity.oneDecimal)%") {
                shell.toasts.send(
                    .buyBackRound(investorID: round.investorID),
                    to: engine,
                    rejected: "The buyout fell through — check the cash."
                )
            }
            Button("Keep them", role: .cancel) {}
        } message: { round in
            let price = engine.state.buybackPrice(for: round, balance: engine.balance)
            Text(
                DecisionPrompt.afterState(
                    delta: -price, cash: engine.state.company.cash, burn: engine.weeklyBurn
                )
                + (round.takesBoardSeat
                    ? " · their ask on \(round.expects.displayName.lowercased()) leaves the room"
                    : "")
            )
        }
    }

    /// WS-B: "Buy them out — $X". Priced on today's valuation at the
    /// premium they bought in at, plus the room's temperature — so it is
    /// cheapest when small and broke and dearest the moment it is
    /// affordable. Greyed, with the price still showing, when the cash is
    /// not there.
    private func buybackButton(_ round: RaisedRound) -> some View {
        let price = engine.state.buybackPrice(for: round, balance: engine.balance)
        let affordable = engine.state.company.cash >= price
        return Button {
            buyingBack = round
        } label: {
            Label("Buy them out — \(price.money)", systemImage: "arrow.uturn.backward.circle")
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .monospacedDigit()
        }
        .buttonStyle(.bordered)
        .tint(Theme.accent)
        .disabled(!affordable)
        .padding(.top, Theme.Spacing.xs)
        .accessibilityLabel(
            affordable
                ? "Buy out \(round.investorName) for \(price.money)"
                : "Buy out \(round.investorName) for \(price.money). Not enough cash."
        )
    }

    // MARK: - Board

    private var boardCard: some View {
        let config = engine.balance.investors
        let pressure = investors.boardPressure
        let expectation = investors.boardExpectation

        return CardView("Board pressure", systemImage: "gauge.with.needle") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                if let earnOut = investors.earnOut {
                    earnOutRow(earnOut)
                    Divider()
                }
                if let expectation {
                    Text(expectation.demand)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("They review every quarter and they watch one thing: \(expectation.displayName.lowercased()).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Pressure")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(pressure.rounded())) / 100")
                            .font(Theme.Typography.number(.caption))
                            .foregroundStyle(pressureTint(pressure))
                    }
                    ProgressView(value: pressure, total: config.boardOustPressure)
                        .tint(pressureTint(pressure))
                        .animation(Theme.Motion.valueChange, value: pressure)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Board pressure \(Int(pressure.rounded())) out of 100")

                // MARK: Iteration 10 — M2 (pitch room)
                // A quarterly verdict used to be something that happened
                // to the founder. Now there is a room to walk into.
                PitchInviteButton(engine: engine, counterpart: .board, prominent: true)
                // MARK: end of Iteration 10 — M2

                if pressure >= config.boardWarningPressure {
                    Label(
                        "They've asked for a plan. Another bad quarter and they'll bring in a CEO.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(Theme.negativeCash)
                }

                // MARK: J2 (record)
                // Rule 7: the number before it lands. What the next review
                // would add for the founder's own quarter, if it met today.
                if investors.hasBoard {
                    let line = engine.state.standingBoardLine(balance: engine.balance)
                    if line.points > 0 {
                        Label(
                            "They read the papers. Next review: +\(Int(line.points.rounded())) for "
                                + standingReasons(line),
                            systemImage: "newspaper.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(Theme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
                // MARK: end J2

                if !investors.reviews.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        ForEach(Array(investors.reviews.suffix(4).enumerated().reversed()), id: \.offset) { _, review in
                            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                                Image(systemName: review.met ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(review.met ? Theme.positiveCash : Theme.negativeCash)
                                // MARK: J2 (record)
                                // The review prints the founder's own
                                // quarter as its own line, when there was one.
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(review.note)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    if review.founderQuarter > 0 {
                                        Text(FounderStanding.boardLineText(points: review.founderQuarter))
                                            .font(Theme.Typography.number(.caption2, weight: .bold))
                                            .foregroundStyle(Theme.negativeCash)
                                    }
                                }
                                // MARK: end J2
                                Spacer(minLength: 0)
                                Text("D\(review.day)")
                                    .font(.caption2)
                                    .monospacedDigit()
                                    .foregroundStyle(.tertiary)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
        }
    }

    // MARK: J2 (record)
    /// "an open case and three rounds of a beef".
    private func standingReasons(_ line: StandingBoardLine) -> String {
        var parts: [String] = []
        if line.openCases > 0 {
            parts.append(line.openCases == 1 ? "an open case" : "\(line.openCases) open cases")
        }
        if line.guiltyVerdicts > 0 {
            parts.append(line.guiltyVerdicts == 1 ? "a guilty verdict" : "\(line.guiltyVerdicts) guilty verdicts")
        }
        if line.beefRounds > 0 {
            parts.append("\(line.beefRounds) round\(line.beefRounds == 1 ? "" : "s") of a public beef")
        }
        if line.unansweredCancellation { parts.append("a cancellation you haven't answered") }
        return parts.formatted(.list(type: .and)) + "."
    }
    // MARK: end J2

    /// The acquirer's seat: what has been paid, what each review is worth,
    /// and how many are left to sit through.
    private func earnOutRow(_ earnOut: EarnOut) -> some View {
        let left = earnOut.remainingReviews
        let tranche = Int((Double(earnOut.price) * engine.balance.investors.earnOutReviewShare).rounded())
        return VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text("Earn-out · \(left) review\(left == 1 ? "" : "s") left")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Spacer()
                Text("\(earnOut.paid.money) of \(earnOut.price.money)")
                    .font(Theme.Typography.number(.subheadline))
            }
            Text(
                "\(earnOut.buyerName) holds the seat. Each review that meets "
                    + "\(earnOut.expectation.displayName.lowercased()) pays \(tranche.money); "
                    + "\(engine.balance.investors.earnOutMissesToOust) misses and they bring in their own CEO."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func pressureTint(_ pressure: Double) -> Color {
        let config = engine.balance.investors
        if pressure >= config.boardWarningPressure { return Theme.negativeCash }
        if pressure >= config.boardWarningPressure / 2 { return Theme.warning }
        return Theme.positiveCash
    }

    // MARK: - IPO

    private var ipoCard: some View {
        let balance = engine.balance
        let blocker = engine.state.ipoBlocker(balance: balance)
        let ready = engine.state.canFileIPO(balance: balance)
        let proceeds = Int(
            (Double(engine.state.companyValuation(balance: balance))
                * balance.investors.ipoValuationMultiple
                * investors.equityRemaining / 100).rounded()
        )

        return CardView("Initial public offering", systemImage: "building.columns.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("The bell, the confetti, and the end of the run. Your stake is bought out at the offer price.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 2) {
                    ipoGateRow(
                        "Valuation of \(balance.investors.ipoValuationFloor.money)",
                        met: engine.state.companyValuation(balance: balance)
                            >= balance.investors.ipoValuationFloor
                    )
                    ipoGateRow(
                        "\(balance.investors.ipoProfitableQuarters) profitable quarters "
                            + "(\(investors.profitableQuarters) so far)",
                        met: investors.profitableQuarters >= balance.investors.ipoProfitableQuarters
                    )
                    if balance.investors.ipoRequiresSubscription {
                        ipoGateRow("A product that bills monthly", met: engine.state.hasSubscriptionProduct)
                    }
                }

                Button {
                    confirmingIPO = true
                } label: {
                    Label(
                        ready ? "File to go public — \(proceeds.money) to you" : "File to go public",
                        systemImage: "bell.fill"
                    )
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.positiveCash)
                .disabled(!ready)
                .accessibilityLabel(
                    ready
                        ? "File to go public. Ends the run with \(proceeds.money) for your stake."
                        : "File to go public. Not available: \(blocker ?? "")"
                )

                if let blocker {
                    Text(blocker)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .confirmationDialog(
            "Take \(engine.state.company.name) public?",
            isPresented: $confirmingIPO,
            titleVisibility: .visible
        ) {
            Button("Ring the bell") {
                engine.send(.fileIPO)
            }
            Button("Not yet", role: .cancel) {}
        } message: {
            Text("This ends the run. Your \(investors.equityRemaining.oneDecimal)% stake sells for \(proceeds.money).")
        }
    }

    private func ipoGateRow(_ label: String, met: Bool) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .font(.caption)
                .foregroundStyle(met ? AnyShapeStyle(Theme.positiveCash) : AnyShapeStyle(.tertiary))
            Text(label)
                .font(.caption)
                .foregroundStyle(met ? .primary : .secondary)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label). \(met ? "Met" : "Not met")")
    }
}

// MARK: - Term sheet

/// The offer on the table, front and centre with both answers on it. The
/// timeline is paused while it stands, and the same choice is available in
/// the root decision sheet — this is the version you can study.
private struct TermSheetCard: View {
    let engine: GameEngine
    let offer: InvestmentOffer

    var body: some View {
        CardView("Term sheet", systemImage: "doc.text.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                    Text(offer.investorName)
                        .font(.system(.headline, design: .rounded))
                    if let persona = engine.content.investors.first(where: { $0.id == offer.investorID }) {
                        Label(persona.flavor.displayName, systemImage: persona.flavor.systemImageName)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, Theme.Spacing.sm)
                            .padding(.vertical, 2)
                            .background(Theme.chipBackground, in: Capsule())
                    }
                    Spacer(minLength: 0)
                }

                if let pitch = engine.content.investors.first(where: { $0.id == offer.investorID })?.pitch {
                    Text("\u{201C}\(pitch)\u{201D}")
                        .font(.subheadline)
                        .italic()
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: Theme.Spacing.sm) {
                    StatPill(systemImage: "dollarsign.circle", value: offer.amount.money)
                    StatPill(systemImage: "chart.pie", value: "\(offer.equity.oneDecimal)%")
                    StatPill(systemImage: "calendar", value: "by D\(offer.respondByDay)")
                }

                Text(
                    offer.takesBoardSeat
                        ? "They take a board seat and will watch \(offer.expects.displayName.lowercased()) every quarter."
                        : "No board seat. They wire the money and leave you alone."
                )
                .font(.caption)
                .foregroundStyle(offer.takesBoardSeat ? Theme.warning : .secondary)
                .fixedSize(horizontal: false, vertical: true)

                // MARK: J2 (record)
                // The sheet says so: it was priced with the case in mind.
                if offer.standingKeyPersonClause {
                    let cut = Int(((1 - engine.balance.founderStanding.keyPersonClauseFactor) * 100).rounded())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("KEY-PERSON CLAUSE: −\(cut)%")
                            .font(Theme.Typography.number(.caption, weight: .bold))
                            .foregroundStyle(Theme.negativeCash)
                        Text("They read about the case. The cheque is smaller by the size of the risk that you go away.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                // MARK: end J2

                if offer.takesBoardSeat {
                    // Patience swings how hard every quarterly verdict
                    // lands by more than four times, and it was nowhere on
                    // the term sheet: two identical cheques could be very
                    // different boards.
                    Text(temperament(offer.patienceWeeks))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if !engine.state.investors.boardExpectations.isEmpty {
                        Text(
                            "You already answer to "
                                + engine.state.investors.boardExpectations
                                    .map { $0.displayName.lowercased() }
                                    .formatted(.list(type: .and))
                                + ". Taking this adds another, and only halves the pressure you're under."
                        )
                        .font(.caption)
                        .foregroundStyle(Theme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }

                // MARK: Iteration 10 — M2 (pitch room)
                // The sheet is negotiable before it is answerable: three
                // exchanges with the person who wrote it move the cheque,
                // the slice and their patience. Both answers below are
                // untouched — the room changes what you are answering,
                // never whether you can.
                PitchInviteButton(engine: engine, counterpart: .investor, prominent: true)
                // MARK: end of Iteration 10 — M2

                HStack(spacing: Theme.Spacing.sm) {
                    Button {
                        engine.send(.acceptInvestment)
                    } label: {
                        Text("Take the money")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)

                    Button {
                        engine.send(.declineInvestment)
                    } label: {
                        Text("Stay independent")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    /// What this investor's patience means in the boardroom, since the
    /// number itself ("20 weeks") tells a player nothing.
    private func temperament(_ patienceWeeks: Int) -> String {
        switch patienceWeeks {
        case ..<16:
            "Impatient money: they react hard to a bad quarter, and just as hard to a good one."
        case ..<28:
            "Ordinary patience — a miss costs you, a recovery buys it back."
        default:
            "Patient money. They will sit through a rough year without reaching for the phone."
        }
    }

}

// MARK: - Equity bar

/// The cap table as one bar: the founder's slice against everyone else's.
private struct EquityBar: View {
    let founderShare: Double

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let founderWidth = width * min(1, max(0, founderShare / 100))
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Theme.accent)
                    .frame(width: founderWidth)
                Rectangle()
                    .fill(Theme.chipBackground)
            }
            .clipShape(Capsule())
        }
        .frame(height: 10)
        .animation(Theme.Motion.valueChange, value: founderShare)
        .accessibilityHidden(true)
    }
}

// MARK: - Formatting

extension Double {
    /// "12.5" / "88" — a percentage without a pointless trailing zero.
    var oneDecimal: String {
        self == rounded() ? String(Int(rounded())) : String(format: "%.1f", self)
    }
}
