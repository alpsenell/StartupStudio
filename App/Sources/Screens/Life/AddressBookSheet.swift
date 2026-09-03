import SwiftUI
import TycoonEngine

/// Everybody the founder has ever met, and everything they own a piece of.
///
/// Contacts persist between events, so this is where a player checks who
/// is worth going back to before planning another Friday — the warmest
/// names come back into the room first. Closed contacts stay, greyed, as
/// the record of what came of them.
struct AddressBookSheet: View {
    let engine: GameEngine

    @State private var selected: Contact?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let networking = engine.state.networking
        let open = networking.contacts.filter(\.isOpen).sorted { $0.rapport > $1.rapport }
        let closed = networking.contacts.filter { !$0.isOpen }

        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    if !networking.holdings.isEmpty {
                        PortfolioCard(networking: networking)
                    }
                    if !networking.grants.isEmpty {
                        CapTableCard(
                            grants: networking.grants,
                            founderEquity: engine.state.founderEquity
                        )
                    }
                    if !open.isEmpty {
                        CardView("In touch", systemImage: "person.2.fill") {
                            VStack(spacing: Theme.Spacing.sm) {
                                ForEach(open) { contact in
                                    ContactRow(contact: contact, day: engine.state.day) {
                                        selected = contact
                                    }
                                }
                            }
                        }
                    }
                    if !closed.isEmpty {
                        CardView("History", systemImage: "clock.arrow.circlepath") {
                            VStack(spacing: Theme.Spacing.sm) {
                                ForEach(closed) { contact in
                                    ContactRow(contact: contact, day: engine.state.day) {
                                        selected = contact
                                    }
                                }
                            }
                        }
                    }
                    if networking.contacts.isEmpty, networking.holdings.isEmpty {
                        ContentUnavailableView(
                            "Nobody yet",
                            systemImage: "person.crop.circle.badge.questionmark",
                            description: Text("Plan a networking weekend and go and meet some people.")
                        )
                        .padding(.top, Theme.Spacing.xl)
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.screenBackground)
            .navigationTitle("Address book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sheet(item: $selected) { contact in
            ContactSheet(engine: engine, contactID: contact.id)
        }
    }
}

// MARK: - Rows

private struct ContactRow: View {
    let contact: Contact
    let day: Int
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: Theme.Spacing.md) {
                PixelPortrait(seed: contact.appearanceSeed, size: 34)
                    .opacity(contact.isOpen ? 1 : 0.5)
                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.name)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(contact.isOpen ? .primary : .secondary)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if contact.isOpen {
                    // Rapport, with the trend the number hides: a contact
                    // not called in a fortnight is on the way out.
                    let fading = ContactWarmth.isFading(contact, day: day)
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(Int(contact.rapport.rounded()))")
                            .font(Theme.Typography.number(.caption))
                            .foregroundStyle(fading ? Theme.warning : Theme.accent)
                        Text(fading ? "Fading — call this week" : "Warm")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(fading ? Theme.warning : Theme.positiveCash)
                    }
                }
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.sm)
            .background(Theme.chipBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.pressableRow)
        .accessibilityLabel("\(contact.name), \(subtitle)")
    }

    private var subtitle: String {
        if let outcome = contact.outcome { return outcome.historyLabel }
        let weeks = max(0, (day - contact.lastMetDay) / 7)
        let seen = weeks == 0 ? "seen this week" : "\(weeks) wk\(weeks == 1 ? "" : "s") ago"
        return "\(contact.archetype.displayName) · \(seen)"
    }
}

// MARK: - Money

private struct PortfolioCard: View {
    let networking: NetworkingState

    var body: some View {
        CardView("Your stakes", systemImage: "chart.pie.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                ForEach(networking.holdings) { holding in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(holding.companyName)
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            Text("\(holding.stakePercent.formatted(.number.precision(.fractionLength(1))))% · paid \(holding.invested.money)")
                                .font(Theme.Typography.number(.caption2, weight: .regular))
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(holding.currentValue.money)
                                .font(Theme.Typography.number(.subheadline))
                            Text(deltaLabel(holding))
                                .font(Theme.Typography.number(.caption2))
                                .foregroundStyle(
                                    holding.currentValue >= holding.invested
                                        ? Theme.positiveCash : Theme.negativeCash
                                )
                        }
                    }
                }
                Text("Paper value. It pays out when one of them is bought — and it goes to zero when one folds.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func deltaLabel(_ holding: Holding) -> String {
        let delta = holding.currentValue - holding.invested
        return "\(delta >= 0 ? "+" : "−")\(abs(delta).money)"
    }
}

private struct CapTableCard: View {
    let grants: [EquityGrant]
    let founderEquity: Double

    var body: some View {
        CardView("What you gave away", systemImage: "person.2.badge.key.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                ForEach(grants) { grant in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(grant.name)
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            Text(grant.reason.displayName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Text("\(grant.percent.formatted(.number.precision(.fractionLength(1))))%")
                            .font(Theme.Typography.number(.subheadline))
                    }
                }
                Divider()
                HStack {
                    Text("Still yours")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(founderEquity.formatted(.number.precision(.fractionLength(1))))%")
                        .font(Theme.Typography.number(.subheadline))
                }
            }
        }
    }
}

// MARK: - Presentation helpers

private extension ContactOutcome {
    var historyLabel: String {
        switch self {
        case .hired: "Works for you"
        case .partner: "Partner"
        case .backed: "You back them"
        case .angel: "Backed you"
        case .romance: "You're together"
        case .lost: "Out of touch"
        }
    }
}

/// Whether a contact is going cold: no contact for a fortnight, or the
/// rapport already down where the next slide closes the door.
enum ContactWarmth {
    static func isFading(_ contact: Contact, day: Int) -> Bool {
        contact.isOpen && (day - contact.lastMetDay >= 14 || contact.rapport < 25)
    }
}
