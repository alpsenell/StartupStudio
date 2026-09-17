import Charts
import PixelKit
import SwiftUI
import TycoonContent
import TycoonEngine

/// Navigation value for pushing a rival's profile inside the Business
/// tab's stack.
struct RivalRoute: Hashable {
    let rivalID: UUID
}

/// One rival, in a room of its own (iteration 6, U3): its studio as a
/// pixel scene — sized by strength, lit by reputation, a fortress for the
/// incumbent, a price tag when it can be bought — its founder and
/// personality, the strength sparkline from the history the engine keeps,
/// its shelf, the history between you compiled from the event log, and
/// the buyout and acquisition actions that already exist, at the bottom.
struct RivalProfileScreen: View {
    let engine: GameEngine
    let rivalID: UUID

    private var rival: Rival? { engine.state.rivals.rival(id: rivalID) }

    var body: some View {
        ScrollView {
            RivalProfileContent(engine: engine, rivalID: rivalID)
                .padding(Theme.Spacing.lg)
        }
        .background(Theme.screenBackground)
        .navigationTitle(rival?.name ?? "Rival")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}

/// The profile's content, separated from its scroll view so the snapshot
/// suite can draw it.
struct RivalProfileContent: View {
    let engine: GameEngine
    let rivalID: UUID

    private var rival: Rival? { engine.state.rivals.rival(id: rivalID) }

    var body: some View {
        if let rival {
            VStack(spacing: Theme.Spacing.lg) {
                RivalStudioCard(engine: engine, rival: rival)
                RivalStrengthCard(engine: engine, rival: rival)
                RivalShelfCard(engine: engine, rival: rival)
                // MARK: J3 (rivals and the market)
                // Where the studio is going and why, and the war it is
                // running. Only once there is something to say.
                if RivalMarketCard.hasSomething(rival, state: engine.state) {
                    RivalMarketCard(engine: engine, rival: rival)
                        .sheet(isPresented: .constant(RivalMarketDebug.liftsCard)) {
                            ScrollView {
                                RivalMarketCard(engine: engine, rival: rival)
                                    .padding(Theme.Spacing.lg)
                            }
                            .background(Theme.screenBackground)
                            .presentationDetents([.medium])
                        }
                }
                // MARK: end J3
                RivalHistoryCard(engine: engine, rival: rival)
                // MARK: Iteration 11 — N2 (people menus)
                // The nemesis strip: the grudge, and taunt / sabotage /
                // bury it. N1's region for the suit and the planted story
                // goes under its own marker, not this one.
                PeopleNemesisCard(engine: engine, rivalID: rivalID)
                // MARK: end of Iteration 11 — N2
                RivalDealCard(engine: engine, rival: rival)
                // MARK: Iteration 11 — N1 (crime and the courtroom)
                // The two offences that are about a person rather than a
                // number live where that person does.
                CrimeRivalCard(engine: engine, rival: rival)
                // MARK: end of Iteration 11 — N1
                // MARK: Iteration 11, wave two — W3 (espionage)
                // The five operations, the folder once there is one, and
                // the mole's countdown. Below the crime card on purpose:
                // the ledger's two offences are the ones a court has a
                // word for, and these are the ones it does not, yet.
                EspionageCard(engine: engine, rivalID: rivalID)
                // MARK: end of Iteration 11, wave two — W3
            }
        } else {
            ContentUnavailableView(
                "Gone from the scene",
                systemImage: "flag.slash",
                description: Text("This studio folded, was bought, or never existed.")
            )
            .padding(.top, Theme.Spacing.xl)
        }
    }
}

// MARK: - The studio

/// The scene, the founder's face, the name in the game's own hand, and
/// the personality that says how they play.
private struct RivalStudioCard: View {
    let engine: GameEngine
    let rival: Rival

    private var terms: RivalAcquisitionTerms {
        RivalAcquisitionTerms(rival: rival, state: engine.state, balance: engine.balance)
    }

    var body: some View {
        let terms = self.terms
        PixelPanel(contentPadding: Theme.Spacing.sm) {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                RivalStudioScene(input: RivalProfileScreen.studioInput(for: rival, forSale: terms.isAffordable))
                    .accessibilityLabel(sceneSummary(forSale: terms.isAffordable))

                HStack(alignment: .top, spacing: Theme.Spacing.md) {
                    PixelPortrait(seed: rival.appearanceSeed, size: 44)
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        // MARK: Iteration 18 — the studio mark: a rival's
                        // comes free from their name, so every rival wears
                        // one whether or not the player picked theirs.
                        HStack(spacing: Theme.Spacing.sm) {
                            RivalMarkView(name: rival.name, size: 18)
                            PixelText(text: rival.name, scale: 2, color: Theme.pixelInk, shadow: true)
                        }
                        // MARK: end of Iteration 18
                        Text("~\(rival.headcount) people · valued around \(rival.valuation(balance: engine.balance).money)")
                            .font(Theme.Typography.number(.caption, weight: .regular))
                            .foregroundStyle(Theme.pixelInk.opacity(0.75))
                            .fixedSize(horizontal: false, vertical: true)
                        if rival.isIncumbent {
                            Label("THE INCUMBENT", systemImage: "building.columns.fill")
                                .font(.caption2.weight(.bold))
                                .kerning(0.5)
                                .foregroundStyle(Theme.warning)
                        }
                    }
                    Spacer(minLength: 0)
                }

                HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                    Label(rival.personality.displayName, systemImage: rival.personality.systemImageName)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.pixelAccent)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, 3)
                        .background(Theme.pixelAccent.opacity(0.12), in: Capsule())
                        .accessibilityLabel("Personality: \(rival.personality.displayName)")
                    Text(rival.personality.blurb)
                        .font(.caption)
                        .foregroundStyle(Theme.pixelInk.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func sceneSummary(forSale: Bool) -> String {
        var parts = [
            "\(rival.name)'s studio, \(RivalProfileScreen.bandName(for: rival.strength)) sized",
            "reputation \(Int(rival.reputation.rounded())) of 100",
        ]
        if rival.isIncumbent { parts.append("a fortress") }
        if forSale { parts.append("for sale") }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Strength

/// The number, its band, and a year of it: the sparkline from the weekly
/// history the engine keeps, with the fold line under it.
private struct RivalStrengthCard: View {
    let engine: GameEngine
    let rival: Rival

    private var series: [Double] {
        rival.strengthHistory.isEmpty ? [rival.strength] : rival.strengthHistory
    }

    var body: some View {
        CardView("Strength", systemImage: "chart.line.uptrend.xyaxis") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.md) {
                    Text("\(Int(rival.strength.rounded()))")
                        .font(Theme.Typography.number(.title2, weight: .bold))
                        .foregroundStyle(Theme.warning)
                        .contentTransition(.numericText())
                        .animation(Theme.Motion.valueChange, value: rival.strength)
                    Text(RivalProfileScreen.bandName(for: rival.strength).capitalized)
                        .font(.caption2.weight(.bold))
                        .kerning(0.4)
                        .foregroundStyle(Theme.warning)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, 3)
                        .background(Theme.warning.opacity(0.15), in: Capsule())
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(rival.reputation.rounded()))")
                            .font(Theme.Typography.number(.subheadline))
                            .foregroundStyle(Theme.accent)
                            .contentTransition(.numericText())
                            .animation(Theme.Motion.valueChange, value: rival.reputation)
                        Text("reputation")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    "Strength \(Int(rival.strength.rounded())) of 100, \(RivalProfileScreen.bandName(for: rival.strength)); reputation \(Int(rival.reputation.rounded())) of 100"
                )

                RivalStrengthSparkline(
                    series: series,
                    foldThreshold: rival.personality == .deepPockets ? nil : engine.balance.rivals.foldThreshold,
                    tint: Theme.warning
                )
                .frame(height: 72)

                Text(footnote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var footnote: String {
        let weeks = rival.strengthHistory.count
        let trend: String
        if weeks >= 2, let first = rival.strengthHistory.first, let last = rival.strengthHistory.last {
            let delta = Int((last - first).rounded())
            trend = delta > 0 ? "up \(delta) over \(weeks) weeks" : delta < 0 ? "down \(-delta) over \(weeks) weeks" : "flat over \(weeks) weeks"
        } else {
            trend = "tracking starts now, one sample a week"
        }
        let fold = rival.personality == .deepPockets
            ? "Somebody rich is patient about this one: it never folds."
            : "Below \(Int(engine.balance.rivals.foldThreshold.rounded())) it folds."
        return "Strength \(trend). Out-selling them in a shared topic wears it down every week. \(fold)"
    }
}

/// A year of strength on a 0…100 scale, with the fold line dashed under
/// it. With one sample it draws the level instead of an empty plot.
private struct RivalStrengthSparkline: View {
    let series: [Double]
    let foldThreshold: Double?
    let tint: Color

    var body: some View {
        Chart {
            if let foldThreshold {
                RuleMark(y: .value("Folds", foldThreshold))
                    .foregroundStyle(Theme.negativeCash.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
            if series.count >= 2 {
                ForEach(Array(series.enumerated()), id: \.offset) { index, value in
                    // The fill is for the shape of a year; under a flat
                    // line it is a solid block, so a flat line goes bare.
                    if varies {
                        AreaMark(x: .value("Week", Double(index)), y: .value("Strength", value))
                            .interpolationMethod(.monotone)
                            .foregroundStyle(tint.opacity(0.14))
                    }
                    LineMark(x: .value("Week", Double(index)), y: .value("Strength", value))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(tint)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                }
            } else if let current = series.first {
                RuleMark(y: .value("Strength", current))
                    .foregroundStyle(tint.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartXScale(domain: 0...Double(max(1, series.count - 1)))
        .chartYScale(domain: 0...100)
        .accessibilityLabel(accessibilityLabel)
    }

    private var varies: Bool {
        guard let low = series.min(), let high = series.max() else { return false }
        return high - low >= 1
    }

    private var accessibilityLabel: String {
        guard series.count >= 2, let first = series.first, let last = series.last else {
            return "Strength chart, one sample"
        }
        return "Strength chart, \(series.count) weeks, from \(Int(first.rounded())) to \(Int(last.rounded()))"
    }
}

// MARK: - The shelf

/// Everything they have shipped, newest first, with the score you would
/// be up against and whether it is still fighting for share.
private struct RivalShelfCard: View {
    let engine: GameEngine
    let rival: Rival

    private var shelf: [RivalProduct] {
        rival.products.sorted { $0.launchDay > $1.launchDay }
    }

    var body: some View {
        CardView("On the market", systemImage: "shippingbox.fill") {
            if shelf.isEmpty {
                Text("Nothing on the market yet.")
                    .emptySectionText()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(shelf.enumerated()), id: \.element.id) { index, product in
                        row(product)
                        if index < shelf.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func row(_ product: RivalProduct) -> some View {
        let faded = !product.isCompeting(on: engine.state.day)
        let topicName = engine.content.topic(product.topicID)?.name ?? product.topicID
        let share = engine.state.rivals.playerShare[product.topicID]
        let score = Int(product.quality.rounded())
        return HStack(spacing: Theme.Spacing.md) {
            Image(systemName: engine.content.topic(product.topicID)?.iconSystemName ?? "shippingbox")
                .font(.subheadline)
                .foregroundStyle(faded ? .secondary : Theme.accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(product.name)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(faded ? .secondary : .primary)
                    .lineLimit(1)
                Text(subtitle(product, topicName: topicName, share: share, faded: faded))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: Theme.Spacing.sm)
            Text("\(score)")
                .font(Theme.Typography.number(.subheadline, weight: .bold))
                .foregroundStyle(faded ? .secondary : Theme.scoreTint(score))
        }
        .padding(.vertical, Theme.Spacing.sm)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(product.name), \(topicName), scores \(score)\(faded ? ", no longer competing" : "")"
        )
    }

    private func subtitle(_ product: RivalProduct, topicName: String, share: Double?, faded: Bool) -> String {
        let launched = "\(topicName) · launched \(MarketFormat.dateLabel(forDay: product.launchDay))"
        if faded { return "\(launched) · faded" }
        if let share, product.isCompeting(on: engine.state.day) {
            return "\(launched) · you hold \(Int((share * 100).rounded()))%"
        }
        return launched
    }
}

// MARK: - The history between you

private struct RivalHistoryCard: View {
    let engine: GameEngine
    let rival: Rival

    private var history: RivalHistory {
        RivalHistory.compile(for: rival.id, state: engine.state, content: engine.content)
    }

    /// The most recent moments; the rest is the journal's.
    private static let shown = 8

    var body: some View {
        let history = self.history
        CardView("Between you", systemImage: "clock.arrow.circlepath") {
            if history.isEmpty {
                Text("Nothing between you yet. Sell into a topic they are in and there will be.")
                    .emptySectionText()
            } else {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    if let summary = history.summary {
                        Text(summary)
                            .font(.footnote.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    VStack(spacing: 0) {
                        let entries = Array(history.entries.prefix(Self.shown))
                        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                            RivalHistoryRow(entry: entry, isLast: index == entries.count - 1)
                        }
                    }
                    if history.entries.count > Self.shown {
                        Text("\(history.entries.count - Self.shown) earlier — the journal has the rest.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }
}

private struct RivalHistoryRow: View {
    let entry: RivalHistory.Entry
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            VStack(spacing: 0) {
                Image(systemName: entry.kind.systemImage)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Theme.ink(on: entry.kind.tint))
                    .frame(width: 22, height: 22)
                    .background(entry.kind.tint, in: Circle())
                if !isLast {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.25))
                        .frame(width: 1.5)
                        .frame(maxHeight: .infinity)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.text)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(MarketFormat.dateLabel(forDay: entry.day))
                    .font(Theme.Typography.number(.caption2, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, isLast ? 0 : Theme.Spacing.md)
            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(entry.text), \(MarketFormat.dateLabel(forDay: entry.day))")
    }
}

extension RivalHistory.Entry.Kind {
    var systemImage: String {
        switch self {
        case .arrived: "flag.fill"
        case .launch: "shippingbox.fill"
        case .copycat: "doc.on.doc.fill"
        case .priceWar: "arrow.down.right.circle.fill"
        case .poachAttempt: "person.fill.questionmark"
        case .poached: "person.fill.xmark"
        case .challenge: "flag.2.crossed.fill"
        case .held: "checkmark.shield.fill"
        case .lost: "xmark.shield.fill"
        case .buyoutOffered: "envelope.badge.fill"
        case .buyoutWithdrawn: "envelope"
        case .sold: "tag.fill"
        case .sponsored: "hammer.fill"
        case .retreated: "flag.checkered"
        case .acquired: "building.2.crop.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .held, .retreated, .acquired: Theme.positiveCash
        case .lost, .poached, .priceWar, .sold: Theme.negativeCash
        case .challenge, .poachAttempt, .buyoutOffered, .sponsored: Theme.warning
        case .arrived, .launch, .copycat: Theme.accent
        case .buyoutWithdrawn: Color.secondary
        }
    }
}

// MARK: - The deal

/// The moves that exist, at the bottom: their standing buyout offer, if
/// this is the studio that made it, and the acquisition. The engine is
/// the enforcer; the gates here mirror `RivalSystem.acquireRival` so the
/// button can explain itself.
private struct RivalDealCard: View {
    let engine: GameEngine
    let rival: Rival

    @State private var confirmingAcquisition = false

    private var terms: RivalAcquisitionTerms {
        RivalAcquisitionTerms(rival: rival, state: engine.state, balance: engine.balance)
    }

    private var offer: BuyoutOffer? {
        guard let pending = engine.state.rivals.pendingBuyout, pending.rivalID == rival.id else { return nil }
        return pending
    }

    var body: some View {
        let terms = self.terms
        CardView("Make a move", systemImage: "handshake.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                if let offer {
                    offerRow(offer)
                    Divider()
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Button {
                        Haptics.tap()
                        confirmingAcquisition = true
                    } label: {
                        Label("Acquire for \(terms.cost.money)", systemImage: "building.2.crop.circle.fill")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .disabled(!terms.isAffordable)

                    Text(terms.blocker ?? "Part of their team and the shelf that beats yours join you; \(rival.name) leaves the market for good.")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                // MARK: K4 (deals and exits)
                // Paper beside cash, and what this studio bids for a sign.
                DealProfileRows(engine: engine, rival: rival)
                // MARK: end K4
                // MARK: T4 (publisher) — the builds this studio publishes
                // for you, each opening its sheet and its buy-out.
                PublisherProfileRows(engine: engine, rival: rival)
                // MARK: end T4
                // MARK: T7 (press and stakes)
                // A piece of them beside the whole: 5, 10 or 25%, or selling
                // what you hold.
                RivalStakeRows(engine: engine, rival: rival)
                    // `-autoRoute t7-stake|t7-offer`: the rows lifted into a
                    // sheet for a screenshot (J3's precedent); never in play.
                    .sheet(isPresented: .constant(RivalStakeDebug.liftsRows(for: rival, state: engine.state))) {
                        ScrollView {
                            RivalStakeRows(engine: engine, rival: rival)
                                .padding(Theme.Spacing.lg)
                        }
                        .background(Theme.screenBackground)
                        .presentationDetents([.medium])
                    }
                // MARK: end T7
            }
        }
        .confirmationDialog(
            "Acquire \(rival.name) for \(terms.cost.money)?",
            isPresented: $confirmingAcquisition,
            titleVisibility: .visible
        ) {
            Button("Acquire for \(terms.cost.money)", role: .destructive) {
                engine.send(.acquireRival(rivalID: rival.id))
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(terms.absorbedShelfCount > 0
                ? "Part of their team and the \(terms.absorbedShelfCount) product\(terms.absorbedShelfCount == 1 ? "" : "s") "
                    + "they're selling join you; \(rival.name) leaves the market for good."
                : "Part of their team joins you; \(rival.name) leaves the market for good.")
        }
    }

    private func offerRow(_ offer: BuyoutOffer) -> some View {
        let daysLeft = max(0, offer.respondByDay - engine.state.day)
        let strategic = engine.state.rivals.lastBuyoutWasStrategic
        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "envelope.badge.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.warning)
                Text("They've offered \(offer.amount.money) for the company")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Text(daysLeft == 0 ? "today" : "\(daysLeft)d")
                    .font(Theme.Typography.number(.caption2))
                    .foregroundStyle(daysLeft <= 1 ? Theme.negativeCash : .secondary)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, 2)
                    .background(Theme.chipBackground, in: Capsule())
            }
            Text(strategic
                ? "A premium for what you built: taking it ends the run as an acquisition."
                : "A distress bid for the name and the desks: taking it ends the run as a sale.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Theme.Spacing.sm) {
                Button {
                    Haptics.tap()
                    engine.send(.acceptBuyout)
                } label: {
                    Text("Sell for \(offer.amount.money)")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Theme.warning)
                Button {
                    Haptics.tap()
                    engine.send(.declineBuyout)
                } label: {
                    Text("Decline")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

/// The acquisition's numbers, mirroring `RivalSystem.acquireRival`'s
/// gates and `absorbShelf`'s rule so the screen can say why a purchase is
/// off and what comes with it. The engine stays the enforcer.
struct RivalAcquisitionTerms {
    let cost: Int
    /// Why the acquisition cannot be made today; nil when it can.
    let blocker: String?
    /// How many of their products would join the studio's line.
    let absorbedShelfCount: Int

    var isAffordable: Bool { blocker == nil }

    init(rival: Rival, state: GameState, balance: BalanceConfig) {
        let valuation = rival.valuation(balance: balance)
        // MARK: T7 (press and stakes) — a stake you hold is part of the
        // price, as `RivalSystem.acquireRival` counts it.
        cost = state.rivalStakeAcquirePrice(
            rivalID: rival.id, fullPrice: Int((Double(valuation) * balance.rivals.acquirePremium).rounded())
        )
        // MARK: end T7

        let dominanceBar = Double(valuation) * balance.rivals.acquireDominanceFactor
        if Double(state.companyValuation(balance: balance)) < dominanceBar {
            blocker = "You're not big enough yet — grow your valuation first"
        } else if state.company.cash < cost {
            blocker = "Need \((cost - state.company.cash).money) more cash"
        } else {
            blocker = nil
        }

        let day = state.day
        var count = 0
        for topicID in Set(state.products.compactMap { product -> String? in
            guard case .released(let info) = product.stage, !info.offMarket else { return nil }
            return product.topicID
        }) {
            let ours = state.products
                .compactMap { product -> Int? in
                    guard product.topicID == topicID, case .released(let info) = product.stage, !info.offMarket
                    else { return nil }
                    return info.averageReviewScore
                }
                .max() ?? 0
            if let theirs = rival.bestProduct(in: topicID, on: day), theirs.quality > Double(ours) {
                count += 1
            }
        }
        absorbedShelfCount = count
    }
}

// MARK: - Mapping onto the scene

extension RivalProfileScreen {
    /// Strength as the studio's size: under 25 a minnow, under 50 small,
    /// under 75 mid, the rest large.
    static func band(for strength: Double) -> StrengthBand {
        if strength < 25 { return .minnow }
        if strength < 50 { return .small }
        if strength < 75 { return .mid }
        return .large
    }

    static func bandName(for strength: Double) -> String {
        switch band(for: strength) {
        case .minnow: "minnow"
        case .small: "small"
        case .mid: "mid-sized"
        case .large: "large"
        }
    }

    /// The scene for a rival. Dusk, so the windows reputation lights read
    /// as lights.
    static func studioInput(for rival: Rival, forSale: Bool) -> RivalStudioInput {
        RivalStudioInput(
            band: band(for: rival.strength),
            reputation: rival.reputation / 100,
            isFortress: rival.isIncumbent,
            forSale: forSale,
            founderSeed: rival.appearanceSeed,
            timeOfDay: .dusk
        )
    }
}

// MARK: - Iteration 11 — N1 (crime and the courtroom)

/// What the founder can do to this studio that a court would have an
/// opinion about: place a story with a friendly desk, or sue them.
///
/// Both read the same gates the engine reads (`crimeRefusal`,
/// `CrimeSystem.sue`'s own conditions), so a button that will not work
/// says why rather than doing nothing.
struct CrimeRivalCard: View {
    let engine: GameEngine
    let rival: Rival

    @State private var arming = false

    private var pendingCase: LegalCase? { engine.state.crime.pendingCase }

    var body: some View {
        CardView("Off the record", systemImage: "eye.trianglebadge.exclamationmark.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                plantStory
                Divider().opacity(0.4)
                suit
            }
        }
    }

    // MARK: Plant a story

    @ViewBuilder
    private var plantStory: some View {
        let refusal = engine.state.crimeRefusal(
            for: .plantStory, rivalID: rival.id, balance: engine.balance
        )
        let config = engine.balance.crime
        VStack(alignment: .leading, spacing: 4) {
            Button(arming ? "Place it — tap again" : "Plant a story about \(rival.name)",
                   systemImage: "newspaper.fill") {
                guard refusal == nil else { return }
                if arming {
                    arming = false
                    engine.send(.commitOffence(offence: .plantStory, rivalID: rival.id))
                    Haptics.commit()
                } else {
                    arming = true
                    Haptics.tap()
                }
            }
            .buttonStyle(.pressable)
            .font(.footnote.weight(.semibold))
            .disabled(refusal != nil)
            Text(refusal?.sentence
                ?? "\(config.plantStoryFee.money) of your own money · their reputation −\(Int(config.plantStoryReputationHit)) · notoriety +\(Int(config.plantStoryNotoriety)). If it is traced back, they come back harder.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Sue them

    @ViewBuilder
    private var suit: some View {
        let fee = engine.balance.crime.suitFilingFee
        let blocked = suitBlocker
        VStack(alignment: .leading, spacing: 4) {
            Button("Sue \(rival.name)", systemImage: "building.columns.fill") {
                engine.send(.sueRival(rivalID: rival.id))
                Haptics.commit()
            }
            .buttonStyle(.pressable)
            .font(.footnote.weight(.semibold))
            .disabled(blocked != nil)
            Text(blocked
                ?? "\(fee.money) filing fee from the company. Win and you take damages and the newest thing off their shelf; lose and you are out the fee and the afternoon.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Rule 7 again: the reasons `CrimeSystem.sue` would return early.
    private var suitBlocker: String? {
        if pendingCase != nil {
            return "You are already in front of a judge. One case at a time."
        }
        if engine.state.company.cash < engine.balance.crime.suitFilingFee {
            return "The company cannot cover the filing fee."
        }
        return nil
    }
}
