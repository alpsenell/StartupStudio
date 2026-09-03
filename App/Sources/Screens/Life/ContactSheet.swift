import SwiftUI
import TycoonEngine

/// One conversation: who this is, how it's going, what the founder can say
/// next, and what deal it could end in.
///
/// The sheet reads the contact out of `engine.state` by id on every body
/// pass rather than holding a copy, so the meters and the offer terms move
/// as the conversation does — an offer that was out of reach two exchanges
/// ago unlocks in place, which is the feedback that makes talking to
/// somebody feel like it is going anywhere.
struct ContactSheet: View {
    let engine: GameEngine
    let contactID: UUID

    @State private var lastLine: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// See `GameShell.shared`: read optionally, because SwiftUI
    /// updates this property for presented content before the
    /// environment is installed and the non-optional form traps there.
    private var shell: GameShell { injectedShell ?? .shared }

    var body: some View {
        NavigationStack {
            ScrollView {
                content
            }
            .background(Theme.screenBackground)
            .navigationTitle(engine.state.networking.contact(contactID)?.name ?? "Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    /// The sheet without its navigation chrome. Split out so a snapshot
    /// can render it: `ImageRenderer` draws a `NavigationStack` as a "no
    /// entry" placeholder, so the interesting half of the screen has to be
    /// reachable on its own.
    @ViewBuilder
    var content: some View {
        let state = engine.state
        if let contact = state.networking.contact(contactID) {
            VStack(spacing: Theme.Spacing.lg) {
                ContactHeader(contact: contact)
                // Everything below spends an evening; the balance is here.
                EveningPips(engine: engine)
                if let lastLine {
                    TranscriptLine(text: lastLine)
                }
                if contact.isOpen, state.isAtNetworkingEvent {
                    topicsCard(contact: contact, state: state)
                }
                offersCard(contact: contact, state: state)
                if contact.isRevealed {
                    DossierCard(contact: contact, balance: engine.balance)
                }
            }
            .padding(Theme.Spacing.lg)
        } else {
            ContentUnavailableView(
                "They've moved on",
                systemImage: "person.slash",
                description: Text("This contact is no longer in your book.")
            )
            .padding(.top, Theme.Spacing.xl)
        }
    }

    // MARK: - What to say

    private func topicsCard(contact: Contact, state: GameState) -> some View {
        let exchangesLeft = state.networking.pendingEvent?.conversationsLeft ?? 0

        return CardView("Say something", systemImage: "bubble.left.and.text.bubble.right.fill") {
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(ConversationTopic.allCases, id: \.self) { topic in
                    TopicRow(
                        topic: topic,
                        detail: topic.detail(for: contact),
                        enabled: exchangesLeft > 0
                    ) {
                        say(topic, to: contact)
                    }
                }
                Text(exchangesLeft > 0
                    ? "\(exchangesLeft) conversation\(exchangesLeft == 1 ? "" : "s") left tonight."
                    : "You're out of steam for tonight.")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func say(_ topic: ConversationTopic, to contact: Contact) {
        let events = engine.send(.talkToContact(contactID: contactID, topic: topic))
        guard let landed = events.compactMap({ event -> Bool? in
            if case .networkingTalk(_, _, let landed, _) = event { return landed }
            return nil
        }).first else { return }

        lastLine = topic.line(landed: landed, name: contact.name)
        if landed { Haptics.commit() }
    }

    // MARK: - Deals

    private func offersCard(contact: Contact, state: GameState) -> some View {
        CardView("On the table", systemImage: "hands.and.sparkles.fill") {
            VStack(spacing: Theme.Spacing.sm) {
                if let outcome = contact.outcome {
                    Text(outcome.closingLine(name: contact.name))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(NetworkingOffer.allCases, id: \.self) { offer in
                        if offer.applies(to: contact, state: state) {
                            OfferRow(
                                offer: offer,
                                terms: offer.terms(for: contact, state: state, balance: engine.balance),
                                blocker: state.networkingOfferBlocker(
                                    offer, contactID: contactID, balance: engine.balance
                                )
                            ) {
                                make(offer, with: contact)
                            }
                        }
                    }
                }
            }
        }
    }

    private func make(_ offer: NetworkingOffer, with contact: Contact) {
        shell.toasts.send(
            .makeNetworkingOffer(contactID: contactID, offer: offer),
            to: engine,
            ack: offer.ack(name: contact.name),
            rejected: "\(contact.name) isn't there yet.",
            icon: offer.systemImage
        )
        dismiss()
    }
}

// MARK: - Header

private struct ContactHeader: View {
    let contact: Contact

    var body: some View {
        CardView(contact.archetype.displayName, systemImage: contact.archetype.systemImage) {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                PixelPortrait(seed: contact.appearanceSeed, size: 56)
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text(contact.name)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                    if let company = contact.companyName {
                        Text("Runs \(company)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    MeterLine(label: "Rapport", value: contact.rapport, tint: Theme.accent)
                    MeterLine(
                        label: "Interest in you", value: contact.interest, tint: Theme.positiveCash
                    )
                }
            }
        }
    }
}

private struct MeterLine: View {
    let label: String
    let value: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(value.rounded()))")
                    .font(Theme.Typography.number(.caption))
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
            }
            Gauge(value: min(max(value / 100, 0), 1)) { EmptyView() }
                .gaugeStyle(.accessoryLinearCapacity)
                .tint(tint)
                .animation(Theme.Motion.valueChange, value: value)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(Int(value.rounded())) of 100")
    }
}

/// The last thing that happened, in one line. Not a chat log — just enough
/// that an exchange has a consequence the player can read.
private struct TranscriptLine: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md)
            .background(Theme.chipBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .transition(.opacity)
            .animation(Theme.Motion.valueChange, value: text)
    }
}

// MARK: - Rows

private struct TopicRow: View {
    let topic: ConversationTopic
    let detail: String
    let enabled: Bool
    let say: () -> Void

    var body: some View {
        Button(action: say) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: topic.systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(enabled ? Theme.accent : .secondary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(topic.displayName)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md)
            .background(Theme.chipBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.pressableRow)
        .disabled(!enabled)
    }
}

private struct OfferRow: View {
    let offer: NetworkingOffer
    let terms: String
    let blocker: String?
    let make: () -> Void

    var body: some View {
        Button(action: make) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: offer.systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(blocker == nil ? Theme.accent : .secondary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(offer.displayName)
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
        .accessibilityLabel("\(offer.displayName). \(terms). \(blocker ?? "")")
    }
}

/// What listening bought: the numbers behind the offers, once the founder
/// has actually asked about them.
private struct DossierCard: View {
    let contact: Contact
    let balance: BalanceConfig

    var body: some View {
        CardView("What they want", systemImage: "doc.text.magnifyingglass") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                DossierRow(label: "Coding", value: "\(Int(contact.skills.coding.rounded()))")
                DossierRow(label: "Design", value: "\(Int(contact.skills.design.rounded()))")
                DossierRow(label: "Marketing", value: "\(Int(contact.skills.marketing.rounded()))")
                Divider()
                DossierRow(label: "Salary ask", value: "\(contact.askingSalary.money)/wk")
                if contact.archetype.hasCompany, contact.companyValuation > 0 {
                    DossierRow(
                        label: "\(contact.companyName ?? "Their company") valued at",
                        value: contact.companyValuation.money
                    )
                }
            }
        }
    }
}

private struct DossierRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(Theme.Typography.number(.caption))
        }
    }
}

// MARK: - Presentation helpers

extension ContactArchetype {
    var systemImage: String {
        switch self {
        case .engineer: "chevron.left.forwardslash.chevron.right"
        case .designer: "paintbrush.pointed.fill"
        case .marketer: "megaphone.fill"
        case .ops: "gearshape.2.fill"
        case .investor: "dollarsign.circle.fill"
        case .founder: "flag.2.crossed.fill"
        }
    }
}

extension ConversationTopic {
    var systemImage: String {
        switch self {
        case .smallTalk: "cloud.sun.fill"
        case .shopTalk: "hammer.fill"
        case .listen: "ear.fill"
        case .pitch: "rectangle.on.rectangle.angled"
        }
    }

    /// What this line is for, in the player's terms — including whether it
    /// can go wrong, which is the only thing separating the four.
    func detail(for contact: Contact) -> String {
        switch self {
        case .smallTalk: "Safe. A little warmer, every time."
        case .shopTalk: "Worth more, but only if you know your subject."
        case .listen: contact.isRevealed
            ? "You already know what they're after."
            : "Find out what they actually want."
        case .pitch: "Makes them care about your company. Cold rooms bite."
        }
    }

    /// One line of consequence for the transcript. Deliberately says
    /// nothing about how much rapport moved: the meters at the top of the
    /// sheet already show that, and saying it twice turns a conversation
    /// back into a spreadsheet.
    func line(landed: Bool, name: String) -> String {
        let first = name.split(separator: " ").first.map(String.init) ?? name
        switch self {
        case .smallTalk:
            return "You talk about nothing much. \(first) relaxes a little."
        case .listen:
            return "You ask about \(first), and then you don't interrupt."
        case .shopTalk:
            return landed
                ? "You get into the weeds with \(first). They're enjoying this."
                : "You get into the weeds, and \(first) checks their phone."
        case .pitch:
            return landed
                ? "\(first) leans in. \"Say that part again.\""
                : "\"Right,\" says \(first), already looking past you."
        }
        // `delta` is deliberately unused in the copy: the meters above
        // already show the number, and saying it twice reads as a spreadsheet.
    }
}

extension NetworkingOffer {
    var systemImage: String {
        switch self {
        case .recruit: "person.badge.plus"
        case .equityHire: "person.2.badge.key.fill"
        case .backThem: "chart.pie.fill"
        case .takeTheirMoney: "banknote.fill"
        case .askOut: "heart.fill"
        }
    }

    /// Whether this offer is even a thing you could say to this person —
    /// as opposed to something they'd say no to, which is the blocker's
    /// job. Keeps "invest in their startup" off the row for somebody who
    /// hasn't got one.
    func applies(to contact: Contact, state: GameState) -> Bool {
        switch self {
        case .recruit, .equityHire: true
        case .backThem: contact.archetype.hasCompany
        case .takeTheirMoney: contact.archetype.isBacker
        case .askOut: state.life.family.stage == .single
        }
    }

    /// The terms this person is actually offering, read from the same
    /// helpers the engine charges against.
    func terms(for contact: Contact, state: GameState, balance: BalanceConfig) -> String {
        let config = balance.networking
        switch self {
        case .recruit:
            return "\(contact.askingSalary.money)/wk on payroll"
        case .equityHire:
            let equity = contact.equityAsk(config)
            return "\(equity.formatted(.number.precision(.fractionLength(1)).locale(Theme.gameLocale)))% of your company, "
                + "\(contact.equityHireSalary(config).money)/wk"
        case .backThem:
            let stake = contact.stakeOnOffer(config)
            return "\(stake.formatted(.number.precision(.fractionLength(1)).locale(Theme.gameLocale)))% of "
                + "\(contact.companyName ?? "their company") for \(contact.stakePrice(config).money)"
        case .takeTheirMoney:
            let terms = contact.angelTerms(config, dealFactor: state.founderDealFactor(balance))
            return "\(terms.amount.money) for "
                + "\(terms.equity.formatted(.number.precision(.fractionLength(1)).locale(Theme.gameLocale)))% of you"
        case .askOut:
            return "See where it goes"
        }
    }

    func ack(name: String) -> String {
        let first = name.split(separator: " ").first.map(String.init) ?? name
        switch self {
        case .recruit: return "\(first) starts Monday."
        case .equityHire: return "\(first) is a partner now."
        case .backThem: return "You're a shareholder in \(first)'s company."
        case .takeTheirMoney: return "\(first)'s money is in the bank."
        case .askOut: return "\(first) said yes."
        }
    }
}

extension ContactOutcome {
    func closingLine(name: String) -> String {
        let first = name.split(separator: " ").first.map(String.init) ?? name
        switch self {
        case .hired: return "\(first) works for you now — they're on the Team tab."
        case .partner: return "\(first) owns a piece of this alongside you."
        case .backed: return "You hold a stake in \(first)'s company."
        case .angel: return "\(first) is on your cap table."
        case .romance: return "You're seeing \(first)."
        case .lost: return "You've lost touch with \(first)."
        }
    }
}
