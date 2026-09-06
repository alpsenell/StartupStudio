import SwiftUI
import TycoonEngine

/// One friend: who they are, where the friendship is, the two things you
/// can give them, and the three deals a long friendship can turn into.
///
/// Like `ContactSheet`, it reads the person out of `engine.state` on every
/// body pass rather than holding a copy — an offer that was out of reach
/// before tonight's evening unlocks in place, which is the whole feedback
/// loop of the feature.
struct FriendSheet: View {
    let engine: GameEngine
    let friendID: UUID

    @Environment(\.dismiss) private var dismiss
    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// See `GameShell.shared`: read optionally, because SwiftUI updates
    /// this property for presented content before the environment is
    /// installed and the non-optional form traps there.
    private var shell: GameShell { injectedShell ?? .shared }

    private var friend: Friend? { engine.state.friend(friendID, content: engine.content) }

    var body: some View {
        NavigationStack {
            ScrollView {
                content
            }
            .background(Theme.screenBackground)
            .navigationTitle(friend?.firstName ?? "Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    /// The sheet without its navigation chrome, so a snapshot can render
    /// it: `ImageRenderer` draws a `NavigationStack` as a placeholder.
    @ViewBuilder
    var content: some View {
        if let friend {
            VStack(spacing: Theme.Spacing.lg) {
                FriendHeader(friend: friend, day: engine.state.day)
                EveningPips(engine: engine)
                if let line = engine.state.lastLine(from: friend.id) {
                    LastLine(text: line.text, day: line.day, today: engine.state.day)
                }
                timeCard(friend)
                offersCard(friend)
                if let loan = friend.loan, loan.outstanding > 0 {
                    loanCard(friend, loan: loan)
                }
            }
            .padding(Theme.Spacing.lg)
        } else {
            ContentUnavailableView(
                "You've lost touch",
                systemImage: "person.slash",
                description: Text("This one isn't in your life any more.")
            )
            .padding(.top, Theme.Spacing.xl)
        }
    }

    // MARK: - What you can give them

    private func timeCard(_ friend: Friend) -> some View {
        let state = engine.state
        let tuning = state.friendTuning
        let call = state.friendCallBlocker(friend.id, content: engine.content)
        let evening = state.friendEveningBlocker(
            friend.id, balance: engine.balance, content: engine.content
        )
        return CardView("Your time", systemImage: "clock.fill") {
            VStack(spacing: Theme.Spacing.sm) {
                ActionRow(
                    icon: "phone.fill",
                    title: "Give them a ring",
                    terms: "Free · bond +\(Int(tuning.callBond)) · once a week",
                    blocker: call
                ) {
                    shell.toasts.send(
                        .callFriend(friendID: friend.id),
                        to: engine,
                        ack: "You called \(friend.firstName).",
                        icon: "phone.fill"
                    )
                }
                ActionRow(
                    icon: "figure.2",
                    title: "Spend an evening with them",
                    terms: eveningTerms(tuning),
                    blocker: evening
                ) {
                    shell.toasts.send(
                        .seeFriend(friendID: friend.id),
                        to: engine,
                        ack: "An evening with \(friend.firstName).",
                        icon: "figure.2"
                    )
                }
            }
        }
    }

    private func eveningTerms(_ tuning: FriendTuning) -> String {
        let wallet = engine.state.life.wallet
        return "−1 evening · −\(tuning.seeCost.money) → \((wallet - tuning.seeCost).money) · bond +\(Int(tuning.seeBond)) · relationships +\(Int(tuning.seeRelationships))"
    }

    // MARK: - What a long friendship becomes

    private func offersCard(_ friend: Friend) -> some View {
        let state = engine.state
        let tuning = state.friendTuning

        return CardView("What this could become", systemImage: "hands.and.sparkles.fill") {
            VStack(spacing: Theme.Spacing.sm) {
                if friend.isOnPayroll {
                    Text("\(friend.firstName) works here now. They're on the team sheet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    if friend.archetype != .neighbour {
                        hireRow(friend, tuning: tuning)
                    }
                    investRow(friend, tuning: tuning)
                    borrowRow(friend, tuning: tuning)
                }
            }
        }
    }

    private func hireRow(_ friend: Friend, tuning: FriendTuning) -> some View {
        let skills = friend.derivedSkills
        let salary = Int((Double(engine.balance.salaryBase)
            + engine.balance.salaryPerSkillPoint * skills.total).rounded())
        return ActionRow(
            icon: "person.badge.plus",
            title: "Ask them to join you",
            terms: "\(salary.money)/wk · \(Int(skills.coding))/\(Int(skills.design))/\(Int(skills.marketing)) · arrives with your whole bond",
            blocker: engine.state.friendHireBlocker(
                friend.id, balance: engine.balance, content: engine.content
            )
        ) {
            shell.toasts.send(
                .hireFriend(friendID: friend.id),
                to: engine,
                ack: "\(friend.firstName) starts Monday.",
                icon: "person.badge.plus"
            )
        }
    }

    private func investRow(_ friend: Friend, tuning: FriendTuning) -> some View {
        let amount = investAmount(friend, tuning: tuning)
        let stake = friend.companyValuation > 0
            ? min(tuning.maximumStakePercent, Double(amount) / Double(friend.companyValuation) * 100)
            : 0
        let wallet = engine.state.life.wallet
        return ActionRow(
            icon: "chart.line.uptrend.xyaxis",
            title: friend.companyName.map { "Back \($0)" } ?? "Back their company",
            terms: friend.companyName == nil
                ? "Nothing to back yet — they haven't started anything"
                : "−\(amount.money) → \((wallet - amount).money) · \(String(format: "%.1f", stake))% of a \(friend.companyValuation.money) company",
            blocker: engine.state.friendInvestBlocker(
                friend.id, amount: amount, content: engine.content
            )
        ) {
            shell.toasts.send(
                .investInFriend(friendID: friend.id, amount: amount),
                to: engine,
                ack: "You backed \(friend.companyName ?? friend.firstName).",
                icon: "chart.line.uptrend.xyaxis"
            )
        }
    }

    /// A quarter of the wallet, floored to the nearest $500, and never
    /// under the minimum cheque — one number on the button rather than a
    /// slider nobody would move.
    private func investAmount(_ friend: Friend, tuning: FriendTuning) -> Int {
        let quarter = engine.state.life.wallet / 4 / 500 * 500
        return max(tuning.minimumInvestment, quarter)
    }

    private func borrowRow(_ friend: Friend, tuning: FriendTuning) -> some View {
        let ceiling = friend.loanCeiling(tuning)
        let amount = max(0, ceiling / 500 * 500)
        let wallet = engine.state.life.wallet
        return ActionRow(
            icon: "hand.raised.fill",
            title: "Ask them for a loan",
            terms: ceiling > 0
                ? "+\(amount.money) → \((wallet + amount).money) · no interest · 26 weeks before it costs the friendship"
                : "Bond \(Int(tuning.borrowBondGate))+ before you could ask",
            blocker: engine.state.friendBorrowBlocker(
                friend.id, amount: amount, content: engine.content
            )
        ) {
            shell.toasts.send(
                .borrowFromFriend(friendID: friend.id, amount: amount),
                to: engine,
                ack: "\(friend.firstName) sent \(amount.money).",
                icon: "hand.raised.fill"
            )
        }
    }

    private func loanCard(_ friend: Friend, loan: FriendLoan) -> some View {
        let due = loan.dueDay(engine.state.friendTuning) - engine.state.day
        let wallet = engine.state.life.wallet
        return CardView("What you owe them", systemImage: "banknote.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Text("Outstanding")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(loan.outstanding.money)
                        .font(Theme.Typography.number(.subheadline))
                }
                Text(due > 0
                    ? "\(due) day\(due == 1 ? "" : "s") before the friendship starts paying for it."
                    : "Overdue. The bond is bleeding \(String(format: "%.2f", engine.state.friendTuning.overdueDecay)) a day.")
                    .font(.caption)
                    .foregroundStyle(due > 0 ? .secondary : Theme.negativeCash)
                    .fixedSize(horizontal: false, vertical: true)
                ActionRow(
                    icon: "arrow.uturn.left",
                    title: "Pay them back in full",
                    terms: "−\(loan.outstanding.money) → \((wallet - loan.outstanding).money) · bond +\(Int(engine.state.friendTuning.repaidBond))",
                    blocker: engine.state.friendRepayBlocker(
                        friend.id, amount: loan.outstanding, content: engine.content
                    )
                ) {
                    shell.toasts.send(
                        .repayFriend(friendID: friend.id, amount: loan.outstanding),
                        to: engine,
                        ack: "Square with \(friend.firstName).",
                        icon: "arrow.uturn.left"
                    )
                }
            }
        }
    }
}

// MARK: - Header

private struct FriendHeader: View {
    let friend: Friend
    let day: Int

    var body: some View {
        CardView(friend.archetype.displayName, systemImage: friend.archetype.systemImage) {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                PixelPortrait(seed: friend.appearanceSeed, size: 56)
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text(friend.name)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                    Text(friend.archetype.blurb)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let company = friend.companyName {
                        Text("Runs \(company)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if friend.hasMovedAway {
                        Text("Abroad since day \(friend.movedAwayDay ?? day) — the bond stopped moving")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.warning)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(friend.bondLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(friend.bond.rounded()))")
                                .font(Theme.Typography.number(.caption))
                                .contentTransition(.numericText())
                        }
                        FriendBondBar(bond: friend.bond, showsValue: false)
                    }
                    Text(silenceLine)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var silenceLine: String {
        let days = max(0, day - friend.lastContactDay)
        if days == 0 { return "You spoke today." }
        if days == 1 { return "You spoke yesterday." }
        return "\(days) days since you spoke."
    }
}

/// The last thing they said, in their own words, on pixel paper.
private struct LastLine: View {
    let text: String
    let day: Int
    let today: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Text(today - day <= 0 ? "Today" : "\(today - day) day\(today - day == 1 ? "" : "s") ago")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.chipBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Rows

/// An action with its consequence on the button and its refusal under it —
/// the same row `ContactSheet` uses for an offer.
private struct ActionRow: View {
    let icon: String
    let title: String
    let terms: String
    let blocker: String?
    let act: () -> Void

    var body: some View {
        Button(action: act) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(blocker == nil ? Theme.accent : .secondary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(terms)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let blocker {
                        Text(blocker)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.warning)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md)
            .background(Theme.chipBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.pressableRow)
        .disabled(blocker != nil)
        .accessibilityLabel("\(title). \(terms). \(blocker ?? "")")
    }
}

// MARK: - Presentation helpers

extension FriendArchetype {
    var systemImage: String {
        switch self {
        case .uniFriend: "chevron.left.forwardslash.chevron.right"
        case .exColleague: "briefcase.fill"
        case .neighbour: "house.fill"
        }
    }
}
