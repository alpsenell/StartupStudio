import SwiftUI
import TycoonContent
import TycoonEngine

/// One thing on the desk: something in the business with a clock on it, or
/// a state the player should know before they pick a section.
struct DeskItem: Identifiable, Equatable {
    let id: String
    let systemImage: String
    let text: String
    /// Days until it matters; `nil` for an open state (a loan, a price war).
    let daysLeft: Int?
    let tint: Color
    let route: Route
    /// The Business section the item lives in, for the pill badges.
    let section: DeskSection

    static func == (lhs: DeskItem, rhs: DeskItem) -> Bool { lhs.id == rhs.id }
}

/// The Business sections a desk item can point at. Mirrors the tab's own
/// segments without depending on the screen's private enum.
enum DeskSection: Hashable {
    case contracts, market, marketing, finances, rivals, investors
}

/// Reads the desk from state.
enum Desk {
    /// Everything with a clock or a state change, most urgent first: dated
    /// items by days left, then the open states.
    static func items(in state: GameState, balance: BalanceConfig, content: ContentCatalog) -> [DeskItem] {
        var items: [DeskItem] = []
        let day = state.day

        // Contracts, with the delivery grade the contract card computes —
        // and, for a rival-sponsored job, what the sponsor will ship.
        for job in state.activeContracts {
            let days = job.deadlineDay - day
            let grade = ContractOutlook.grade(
                hasWork: job.skillDays > 0,
                projectedQuality: job.projectedQuality,
                balance: balance,
                sponsoredTopic: job.isSponsored
                    ? job.topicID.map { content.topic($0)?.name ?? $0 }
                    : nil
            )
            items.append(
                DeskItem(
                    id: "contract-\(job.id)",
                    systemImage: "briefcase.fill",
                    text: days < 0
                        ? "\(job.clientName) is overdue — \(grade.label)"
                        : "\(job.clientName) · \(grade.promise ?? grade.label)",
                    daysLeft: max(0, days),
                    tint: days <= 3 ? Theme.negativeCash : grade.tint,
                    route: .contracts,
                    section: .contracts
                )
            )
        }

        // A term sheet on the table.
        if let offer = state.investors.pendingOffer {
            items.append(
                DeskItem(
                    id: "offer-\(offer.investorID)",
                    systemImage: "doc.text.fill",
                    text: "\(offer.investorName) offered \(offer.amount.money) for \(offer.equity.oneDecimal)%",
                    daysLeft: max(0, offer.respondByDay - day),
                    tint: Theme.accent,
                    route: .investors,
                    section: .investors
                )
            )
        }

        // MARK: Iteration 10 — M2 (pitch room)
        // The press want twenty minutes before a launch. This is the only
        // one of the four conversations with no card of its own to sit
        // on, so the desk is where it is offered.
        if state.pitchBlocker(
            for: .journalist, balance: balance, content: content
        ) == nil {
            items.append(
                DeskItem(
                    id: "pitch-journalist",
                    systemImage: "mic.fill",
                    text: "A reporter wants twenty minutes before the launch",
                    // MARK: V2 (ux: one inbox, one home per thing)
                    // C5: the interview's real deadline — the day the build
                    // ships, or the end of a shipped build's launch week.
                    daysLeft: Self.interviewDaysLeft(in: state, balance: balance, content: content),
                    // MARK: end V2
                    tint: Theme.accent,
                    // The interview is offered under the war room's press
                    // strip, which is where the outlet's name is; the row
                    // is the pointer, not the room.
                    route: .warRoom,
                    section: .contracts
                )
            )
        }
        // MARK: end of Iteration 10 — M2

        // Campaigns about to end.
        for campaign in state.campaigns where campaign.endDay >= day && campaign.endDay - day <= 7 {
            let product = state.product(id: campaign.productID)?.name ?? "A"
            items.append(
                DeskItem(
                    id: "campaign-\(campaign.id)",
                    systemImage: "megaphone.fill",
                    text: "\(product) campaign ends",
                    daysLeft: campaign.endDay - day,
                    tint: .secondary,
                    route: .marketing,
                    section: .marketing
                )
            )
        }

        // Booms and crashes in a topic the studio sells in, this fortnight.
        let soldTopics = Set(
            state.products.compactMap { product -> String? in
                guard case .released(let info) = product.stage, !info.offMarket else { return nil }
                return product.topicID
            }
        )
        for event in state.market.recentEvents where day - event.day <= 14 && soldTopics.contains(event.topicID) {
            let topic = content.topic(event.topicID)?.name ?? event.topicID
            let ago = day - event.day
            items.append(
                DeskItem(
                    id: "market-\(event.topicID)-\(event.day)",
                    systemImage: event.kind == .boom ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis",
                    text: "\(topic) \(event.kind == .boom ? "boomed" : "crashed") \(ago == 0 ? "today" : "\(ago) day\(ago == 1 ? "" : "s") ago")",
                    daysLeft: nil,
                    tint: event.kind == .boom ? Theme.positiveCash : Theme.negativeCash,
                    route: .marketReport(topicID: event.topicID),
                    section: .market
                )
            )
        }

        // A rival's price war in a topic the studio sells in.
        for rival in state.rivals.rivals where rival.isInPriceWar(on: day) {
            guard let topicID = rival.priceWarTopicID, soldTopics.contains(topicID) else { continue }
            let topic = content.topic(topicID)?.name ?? topicID
            items.append(
                DeskItem(
                    id: "war-\(rival.id)",
                    systemImage: "flag.2.crossed.fill",
                    text: "\(rival.name) is running a price war in \(topic)",
                    // MARK: V2 (ux: one inbox, one home per thing)
                    // C5: the answer window, while the war is unanswered;
                    // an answered war is an open state again.
                    daysLeft: Self.priceWarDaysLeft(rival, in: state, balance: balance),
                    // MARK: end V2
                    tint: Theme.warning,
                    route: .rivals,
                    section: .rivals
                )
            )
        }

        // A category fight with a clock on it (WS-A).
        for challenge in state.rivals.challenges {
            let rival = state.rivals.rival(id: challenge.rivalID)?.name ?? "A rival"
            let topic = content.topic(challenge.topicID)?.name ?? challenge.topicID
            let share = state.rivals.share(for: challenge.topicID)
            let holding = share >= balance.rivals.depth.challengeHoldShare
            items.append(
                DeskItem(
                    id: "challenge-\(challenge.id)",
                    systemImage: "flag.2.crossed.fill",
                    text: "\(rival) is challenging \(topic) · you hold \(Int((share * 100).rounded()))%",
                    daysLeft: max(0, challenge.settlesDay - day),
                    tint: holding ? Theme.warning : Theme.negativeCash,
                    route: .rivals,
                    section: .rivals
                )
            )
        }

        // The bank.
        if state.loanBalance > 0 {
            items.append(
                DeskItem(
                    id: "loan",
                    systemImage: "banknote.fill",
                    text: "\(state.loanBalance.money) on loan · interest posts weekly",
                    daysLeft: nil,
                    tint: .secondary,
                    route: .finances,
                    section: .finances
                )
            )
        }

        // A board that is losing patience.
        if state.investors.boardPressure >= 60 {
            items.append(
                DeskItem(
                    id: "board",
                    systemImage: "chart.pie.fill",
                    text: "Board pressure \(Int(state.investors.boardPressure.rounded())) of 100",
                    daysLeft: nil,
                    tint: state.investors.boardPressure >= 80 ? Theme.negativeCash : Theme.warning,
                    route: .investors,
                    section: .investors
                )
            )
        }

        return items.sorted { lhs, rhs in
            switch (lhs.daysLeft, rhs.daysLeft) {
            case let (l?, r?): l < r
            case (.some, .none): true
            case (.none, .some): false
            case (.none, .none): lhs.id < rhs.id
            }
        }
    }

    // MARK: V2 (ux: one inbox, one home per thing)

    /// C5: days until the reporter's twenty minutes stop being on offer —
    /// the build the press want ships (`interviewableProductID`'s first
    /// case), or a build that shipped leaves its launch week (its second).
    /// U1 found the row undated, which kept it off the badge and the inbox.
    static func interviewDaysLeft(in state: GameState, balance: BalanceConfig, content: ContentCatalog) -> Int? {
        let week = GameState.daysPerWeek
        if let eta = state.shipETAs(balance: balance, content: content).first(where: { $0.daysAway <= week }) {
            return max(0, eta.daysAway)
        }
        let launched = state.products.compactMap { product -> Int? in
            guard case .released(let info) = product.stage, !info.offMarket,
                  state.day - info.launchDay <= week
            else { return nil }
            return info.launchDay
        }.max()
        return launched.map { max(0, $0 + week - state.day) }
    }

    /// C5: days left to answer a rival's price war — the same window the
    /// decision sheet's question closes on (`RivalMarket.answerDeadline`).
    /// `nil` once it is answered or the window has gone: the war is then
    /// a state, not a question.
    static func priceWarDaysLeft(_ rival: Rival, in state: GameState, balance: BalanceConfig) -> Int? {
        guard state.rivalMarket.answer(to: rival) == nil,
              let deadline = RivalMarket.answerDeadline(rival, balance: balance),
              deadline >= state.day
        else { return nil }
        return deadline - state.day
    }

    // MARK: end V2
}

/// The card above the Business tab's pill bar: what has a clock on it, most
/// urgent first, each row routing into its section. Collapses to one line
/// when the desk is clear.
struct DeskCard: View {
    let items: [DeskItem]
    let onRoute: (Route) -> Void

    var body: some View {
        CardView("On the desk", systemImage: "tray.full.fill") {
            if items.isEmpty {
                // U1 (C8): the Contracts section's empty Active card folds
                // into this line; every running contract is a desk row.
                Text("Nothing on the desk. No contracts running.")
                    .emptySectionText()
            } else {
                VStack(spacing: 0) {
                    ForEach(items) { item in
                        row(item)
                        if item.id != items.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func row(_ item: DeskItem) -> some View {
        Button {
            Haptics.tap()
            onRoute(item.route)
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: item.systemImage)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(item.tint)
                    .frame(width: 22)
                Text(item.text)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: Theme.Spacing.xs)
                if let days = item.daysLeft {
                    Text(days == 0 ? "today" : "\(days)d")
                        .font(Theme.Typography.number(.caption))
                        .foregroundStyle(days <= 3 ? Theme.negativeCash : .secondary)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, 2)
                        .background(Theme.chipBackground, in: Capsule())
                }
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, Theme.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressableRow)
        .accessibilityLabel(
            item.daysLeft.map { "\(item.text), \($0 == 0 ? "today" : "\($0) days")" } ?? item.text
        )
    }
}
