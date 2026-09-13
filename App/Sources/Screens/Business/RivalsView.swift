import SwiftUI
import TycoonContent
import TycoonEngine

/// The Rivals segment of the Business tab: who you are up against, what
/// they have shipped, how the market is split in every topic you share,
/// and the acquisition move once you can afford (and dominate) them.
struct RivalsView: View {
    let engine: GameEngine

    /// Strongest first; ties break on the id so the order is stable.
    private var rivals: [Rival] {
        engine.state.rivals.rivals.sorted { lhs, rhs in
            if lhs.strength != rhs.strength { return lhs.strength > rhs.strength }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    /// Topics where the player and at least one rival both have something
    /// on the market, worst share first — the ones that need attention.
    private var contestedTopics: [(topicID: String, share: Double)] {
        engine.state.rivals.playerShare
            .filter { $0.value < 1.0 }
            .map { (topicID: $0.key, share: $0.value) }
            .sorted { lhs, rhs in
                if lhs.share != rhs.share { return lhs.share < rhs.share }
                return lhs.topicID < rhs.topicID
            }
    }

    var body: some View {
        // MARK: K4 (deals and exits)
        // A sign that is up leads the segment; one that is not waits at
        // the foot, after the studios that might bid.
        if engine.state.rivals.listing != nil || DealDebug.cardLeads {
            BusinessSectionHeader(title: engine.state.rivals.listing != nil ? "For sale" : "Sell the company", systemImage: "signpost.right.fill")
            DealSignCard(engine: engine)
        }
        // MARK: end K4
        // MARK: T7 (press and stakes)
        // What you own of them, at the top once you own something.
        if !engine.state.rivals.stakes.isEmpty {
            BusinessSectionHeader(title: "Your stakes", systemImage: "chart.pie.fill")
            RivalHoldingsCard(engine: engine)
        }
        // MARK: end T7
        if !contestedTopics.isEmpty {
            BusinessSectionHeader(title: "Head to head", systemImage: "chart.bar.xaxis")
            ForEach(contestedTopics, id: \.topicID) { entry in
                TopicBattleCard(engine: engine, topicID: entry.topicID, share: entry.share)
            }
        }

        BusinessSectionHeader(title: "Rival studios", systemImage: "flag.2.crossed.fill")

        if rivals.isEmpty {
            EmptyStateCard(
                message: "The scene is quiet.",
                systemImage: "flag.2.crossed",
                hint: "Rival studios show up as the market grows.",
                tint: Theme.warning
            )
        } else {
            ForEach(rivals) { rival in
                RivalCard(engine: engine, rival: rival)
            }
        }
        // MARK: K4 (deals and exits)
        if engine.state.rivals.listing == nil && !DealDebug.cardLeads {
            BusinessSectionHeader(title: "Sell the company", systemImage: "signpost.right.fill")
            DealSignCard(engine: engine)
        }
        // MARK: end K4
    }
}

// MARK: - Head to head

/// One contested topic: the player's best product against the best thing
/// every rival has in it, and the share bar between them.
private struct TopicBattleCard: View {
    let engine: GameEngine
    let topicID: String
    let share: Double

    private var topicName: String {
        engine.content.topic(topicID)?.name ?? topicID
    }

    /// The player's best on-market product in this topic.
    private var playerEntry: (name: String, score: Int)? {
        engine.state.products
            .compactMap { product -> (String, Int)? in
                guard product.topicID == topicID,
                      case .released(let info) = product.stage,
                      !info.offMarket
                else { return nil }
                return (product.name, info.averageReviewScore)
            }
            .max { $0.1 < $1.1 }
    }

    private var competitors: [(rival: Rival, product: RivalProduct)] {
        engine.state.rivals.competitors(in: topicID, on: engine.state.day)
    }

    private var priceWar: Rival? {
        competitors
            .map(\.rival)
            .first { $0.isInPriceWar(on: engine.state.day) && $0.priceWarTopicID == topicID }
    }

    /// The category fight in progress here, if any (WS-A).
    private var challenge: CategoryChallenge? {
        engine.state.rivals.challenge(in: topicID)
    }

    var body: some View {
        CardView(topicName, systemImage: "target") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(Int((share * 100).rounded()))% of the market")
                        .font(Theme.Typography.number(.subheadline))
                        .contentTransition(.numericText())
                        .foregroundStyle(shareTint)
                    Spacer()
                    if share >= RivalDepthTuning.dominanceShare {
                        Text("YOU LEAD")
                            .font(.caption2.weight(.bold))
                            .kerning(0.5)
                            .foregroundStyle(Theme.positiveCash)
                    }
                }

                ShareBar(share: share)
                    .accessibilityLabel(
                        "You hold \(Int((share * 100).rounded())) percent of the \(topicName) market"
                    )

                if let player = playerEntry {
                    contender(
                        name: player.name, score: player.score, subtitle: "yours", isPlayer: true
                    )
                }
                ForEach(competitors.prefix(3), id: \.product.id) { entry in
                    contender(
                        name: entry.product.name,
                        score: Int(entry.product.quality.rounded()),
                        subtitle: entry.rival.name,
                        isPlayer: false
                    )
                }

                if let priceWar {
                    Label(
                        "\(priceWar.name) is running a price war here — "
                            + "\(Int(RivalDepthTuning.priceWarSharePenalty * 100))% of your share, "
                            + "until day \(priceWar.priceWarUntilDay ?? engine.state.day).",
                        systemImage: "arrow.down.right.circle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(Theme.negativeCash)
                    .fixedSize(horizontal: false, vertical: true)
                }

                if let challenge {
                    challengeBanner(challenge)
                }
            }
        }
    }

    /// The fight and its clock: who launched what, the share that decides
    /// it, and whether the player is holding it today.
    private func challengeBanner(_ challenge: CategoryChallenge) -> some View {
        let depth = engine.balance.rivals.depth
        let rivalName = engine.state.rivals.rival(id: challenge.rivalID)?.name ?? "A rival"
        let daysLeft = max(0, challenge.settlesDay - engine.state.day)
        let holding = share >= depth.challengeHoldShare
        return VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.sm) {
                Label("CHALLENGE", systemImage: "flag.2.crossed.fill")
                    .font(.caption2.weight(.bold))
                    .kerning(0.5)
                    .foregroundStyle(Theme.warning)
                Spacer(minLength: Theme.Spacing.xs)
                Text(daysLeft == 0 ? "settles today" : "settles in \(daysLeft)d")
                    .font(Theme.Typography.number(.caption2))
                    .foregroundStyle(daysLeft <= 7 ? Theme.negativeCash : .secondary)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, 2)
                    .background(Theme.chipBackground, in: Capsule())
            }
            Text(
                "\(rivalName) launched \(challenge.productName) (\(Int(challenge.quality.rounded()))) here. "
                    + "Hold \(Int((depth.challengeHoldShare * 100).rounded()))% when it settles and they lose "
                    + "\(Int(depth.heldRivalStrengthLoss)) strength; lose it and your standing here drops "
                    + "\(Int(depth.lostStandingLoss))."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            Text(
                challenge.conceded
                    ? (holding ? "You let it go — and you're holding it anyway." : "You let it go.")
                    : (holding ? "You're holding it." : "You're not holding it.")
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(holding ? Theme.positiveCash : Theme.negativeCash)
        }
        .padding(Theme.Spacing.sm)
        .background(Theme.chipBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var shareTint: Color {
        if share >= RivalDepthTuning.dominanceShare { return Theme.positiveCash }
        if share >= 0.45 { return Theme.warning }
        return Theme.negativeCash
    }

    private func contender(name: String, score: Int, subtitle: String, isPlayer: Bool) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: isPlayer ? "person.fill" : "flag.fill")
                .font(.caption2)
                .foregroundStyle(isPlayer ? Theme.accent : .secondary)
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 0) {
                Text(name)
                    .font(.system(.subheadline, design: .rounded).weight(isPlayer ? .semibold : .regular))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: Theme.Spacing.sm)
            Text("\(score)")
                .font(Theme.Typography.number(.caption, weight: .bold))
                .foregroundStyle(Theme.scoreTint(score))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(subtitle), scores \(score)")
    }
}

/// The split of one topic's demand: the player's slice against everyone
/// else's.
private struct ShareBar: View {
    let share: Double

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Theme.accent)
                    .frame(width: proxy.size.width * min(1, max(0, share)))
                Rectangle()
                    .fill(Theme.chipBackground)
            }
            .clipShape(Capsule())
        }
        .frame(height: 10)
        .animation(Theme.Motion.valueChange, value: share)
    }
}

// MARK: - Rival card

/// One rival studio. Internal rather than private so the snapshot suite
/// can draw the incumbent's card.
struct RivalCard: View {
    let engine: GameEngine
    let rival: Rival

    @State private var confirmingAcquisition = false

    private var shipped: [RivalProduct] {
        // Newest first: what they are selling right now matters most.
        rival.products.sorted { $0.launchDay > $1.launchDay }
    }

    /// A topic they are winning against the player, if any — the line they
    /// would say to your face.
    private var isBeatingPlayer: Bool {
        rival.competingProducts(on: engine.state.day).contains { product in
            engine.state.rivals.share(for: product.topicID) < 0.5
        }
    }

    var body: some View {
        CardView(rival.name, systemImage: "flag.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                // The card's head opens the profile (U3): the studio
                // scene, the strength history, the history between you.
                NavigationLink(value: RivalRoute(rivalID: rival.id)) {
                    HStack(spacing: Theme.Spacing.sm) {
                        PixelPortrait(seed: rival.appearanceSeed)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("~\(rival.headcount) people")
                                .font(Theme.Typography.number(.subheadline))
                            Text("Valued around \(rival.valuation(balance: engine.balance).money)")
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        personalityBadge
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.pressableRow)
                .accessibilityHint("Opens \(rival.name)'s profile")

                Text(rival.personality.blurb)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if rival.isIncumbent {
                    incumbentSection
                }

                if isBeatingPlayer {
                    Text(rival.personality.taunt)
                        .font(.caption)
                        .italic()
                        .foregroundStyle(Theme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }

                meter("Strength", value: rival.strength, tint: Theme.warning)
                meter("Reputation", value: rival.reputation, tint: Theme.accent)

                if shipped.isEmpty {
                    Text("Nothing on the market yet.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("On the market")
                            .font(.caption2.weight(.semibold))
                            .textCase(.uppercase)
                            .kerning(0.5)
                            .foregroundStyle(.tertiary)
                        ForEach(shipped.prefix(4)) { product in
                            productRow(product)
                        }
                    }
                }

                acquireRow
            }
        }
        .confirmationDialog(
            "Acquire \(rival.name) for \(acquisitionCost.money)?",
            isPresented: $confirmingAcquisition,
            titleVisibility: .visible
        ) {
            Button("Acquire for \(acquisitionCost.money)", role: .destructive) {
                engine.send(.acquireRival(rivalID: rival.id))
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(absorbedShelfCount > 0
                ? "Part of their team and the \(absorbedShelfCount) product\(absorbedShelfCount == 1 ? "" : "s") "
                    + "they're selling join you; \(rival.name) leaves the market for good."
                : "Part of their team joins you; \(rival.name) leaves the market for good.")
        }
    }

    // MARK: The incumbent

    /// The giant in the player's best markets: which two, how much of
    /// each the player holds today, and the retreat clock — running only
    /// while both are held.
    private var incumbentSection: some View {
        let state = engine.state
        let depth = engine.balance.rivals.depth
        let holdShare = depth.challengeHoldShare
        let topics = rival.focusTopicIDs
        let heldAll = !topics.isEmpty && topics.allSatisfy { (state.rivals.playerShare[$0] ?? 0) >= holdShare }
        let weeksHeld = state.rivals.incumbentHeldSinceDay.map { (state.day - $0) / 7 } ?? 0
        let weeksLeft = max(0, depth.incumbentRetreatWeeks - weeksHeld)
        return VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Label("THE INCUMBENT", systemImage: "building.columns.fill")
                .font(.caption2.weight(.bold))
                .kerning(0.5)
                .foregroundStyle(Theme.warning)
            Text(
                "Founded into your best markets, with money to lose. Hold "
                    + "\(Int((holdShare * 100).rounded()))% of both for \(depth.incumbentRetreatWeeks) weeks "
                    + "and they leave — worth +\(Int(depth.incumbentRetreatReputationGain)) reputation and "
                    + "+\(Int(depth.incumbentRetreatStandingGain)) standing in each."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            ForEach(topics, id: \.self) { topicID in
                let share = state.rivals.playerShare[topicID]
                let holding = (share ?? 0) >= holdShare
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: holding ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(holding ? Theme.positiveCash : Theme.negativeCash)
                        .frame(width: 14)
                    Text(topicName(topicID))
                        .font(.system(.subheadline, design: .rounded))
                    Spacer(minLength: Theme.Spacing.xs)
                    Text(share.map { "\(Int(($0 * 100).rounded()))%" } ?? "nothing live")
                        .font(Theme.Typography.number(.caption, weight: .bold))
                        .foregroundStyle(holding ? Theme.positiveCash : Theme.negativeCash)
                }
                .accessibilityElement(children: .combine)
            }
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "clock.fill")
                    .font(.caption2)
                    .foregroundStyle(heldAll ? Theme.positiveCash : .secondary)
                    .frame(width: 14)
                Text(
                    heldAll
                        ? (weeksLeft == 0 ? "They retreat this week." : "Holding both — they retreat in \(weeksLeft) wk.")
                        : "The retreat clock is stopped until you hold both."
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(heldAll ? Theme.positiveCash : .secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Theme.Spacing.sm)
        .background(Theme.chipBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var personalityBadge: some View {
        Label(rival.personality.displayName, systemImage: rival.personality.systemImageName)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, 3)
            .background(Theme.chipBackground, in: Capsule())
            .accessibilityLabel("\(rival.personality.displayName): \(rival.personality.blurb)")
    }

    private func productRow(_ product: RivalProduct) -> some View {
        let faded = !product.isCompeting(on: engine.state.day)
        return HStack(spacing: Theme.Spacing.sm) {
            Text(product.name)
                .font(.system(.subheadline, design: .rounded))
                .lineLimit(1)
                .foregroundStyle(faded ? .secondary : .primary)
            Text(topicName(product.topicID))
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Spacer(minLength: Theme.Spacing.xs)
            if faded {
                Text("faded")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Text("\(Int(product.quality.rounded()))")
                .font(Theme.Typography.number(.caption, weight: .bold))
                .foregroundStyle(Theme.scoreTint(Int(product.quality.rounded())))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(product.name), \(topicName(product.topicID)), scores "
                + "\(Int(product.quality.rounded()))\(faded ? ", no longer competing" : "")"
        )
    }

    private func topicName(_ id: String) -> String {
        engine.content.topic(id)?.name ?? id
    }

    private func meter(_ label: String, value: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(value.rounded()))")
                    .font(Theme.Typography.number(.caption, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: value, total: 100)
                .tint(tint)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(Int(value.rounded())) out of 100")
    }

    // MARK: Acquisition

    /// What comes with the sale, mirroring `RivalSystem.acquireRival`'s
    /// rule (the engine stays the enforcer): in each category the player
    /// is in, their best product there if it beats the player's.
    private var absorbedShelfCount: Int {
        let state = engine.state
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
        return count
    }

    private var acquisitionCost: Int {
        Int((Double(rival.valuation(balance: engine.balance))
            * engine.balance.rivals.acquirePremium).rounded())
    }

    /// Why the acquisition button is disabled, mirroring the engine's
    /// `acquireRival` gates (the engine stays the enforcer).
    private var acquisitionBlocker: String? {
        let balance = engine.balance
        let state = engine.state
        let dominanceBar = Double(rival.valuation(balance: balance))
            * balance.rivals.acquireDominanceFactor
        if Double(state.companyValuation(balance: balance)) < dominanceBar {
            return "You're not big enough yet — grow your valuation first"
        }
        if state.company.cash < acquisitionCost {
            return "Need \((acquisitionCost - state.company.cash).money) more cash"
        }
        return nil
    }

    private var acquireRow: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Button {
                confirmingAcquisition = true
            } label: {
                Label("Acquire for \(acquisitionCost.money)", systemImage: "building.2.crop.circle.fill")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .disabled(acquisitionBlocker != nil)

            if let blocker = acquisitionBlocker {
                Text(blocker)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }
}
