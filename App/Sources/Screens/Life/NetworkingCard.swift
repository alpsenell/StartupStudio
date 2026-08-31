import SwiftUI
import TycoonEngine

/// The Life tab's door into the networking floor, plus the two things that
/// outlive any one evening: the address book, and the stakes the founder
/// personally holds in other people's studios.
///
/// With a room open the card is a single loud button — the evening is
/// time-limited and the player should not have to hunt for it. With no
/// room open it is a quiet summary and a nudge toward planning a Friday.
struct NetworkingCard: View {
    let engine: GameEngine

    @State private var showingRoom = false
    @State private var showingBook = false

    var body: some View {
        let state = engine.state
        let networking = state.networking

        CardView("People", systemImage: "person.2.wave.2.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                if let event = networking.pendingEvent {
                    OpenRoomRow(event: event, day: state.day) { showingRoom = true }
                } else {
                    Text(networking.contacts.isEmpty
                        ? "You don't know anybody yet. Plan a networking weekend and go and meet some people."
                        : "No event on. Plan a networking weekend to get back out there.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: Theme.Spacing.md) {
                    SummaryTile(
                        title: "Contacts",
                        value: "\(networking.contacts.count(where: \.isOpen))",
                        caption: "people who'd take your call"
                    )
                    SummaryTile(
                        title: "Portfolio",
                        value: networking.portfolioValue.money,
                        caption: portfolioCaption(networking)
                    )
                }

                Button {
                    showingBook = true
                } label: {
                    Label("Address book", systemImage: "book.pages.fill")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.sm)
                }
                .buttonStyle(.bordered)
                .disabled(networking.contacts.isEmpty && networking.holdings.isEmpty)
            }
        }
        .sheet(isPresented: $showingRoom) {
            NetworkingVenueSheet(engine: engine)
        }
        .sheet(isPresented: $showingBook) {
            AddressBookSheet(engine: engine)
        }
    }

    /// Gain or loss against what the founder actually paid, so the tile is
    /// a position rather than a number with no reference.
    private func portfolioCaption(_ networking: NetworkingState) -> String {
        guard !networking.holdings.isEmpty else { return "no stakes yet" }
        let delta = networking.portfolioValue - networking.portfolioInvested
        let stakes = networking.holdings.count
        return "\(stakes) stake\(stakes == 1 ? "" : "s") · \(delta >= 0 ? "+" : "−")\(abs(delta).money)"
    }
}

// MARK: - Rows

private struct OpenRoomRow: View {
    let event: NetworkingEvent
    let day: Int
    let enter: () -> Void

    var body: some View {
        Button(action: enter) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "sparkles")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("You're at the \(event.venue.displayName)")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("\(event.contactIDs.count) people · \(event.conversationsLeft) conversation\(event.conversationsLeft == 1 ? "" : "s") left")
                        .font(Theme.Typography.number(.caption, weight: .regular))
                        .foregroundStyle(.secondary)
                    Text("Closes in \(max(0, event.expiresOnDay - day)) day\(max(0, event.expiresOnDay - day) == 1 ? "" : "s")")
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(Theme.warning)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md)
            .background(
                Theme.accent.opacity(0.12),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
        }
        .buttonStyle(.pressableRow)
    }
}

private struct SummaryTile: View {
    let title: String
    let value: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(Theme.Typography.number(.subheadline))
                .foregroundStyle(.primary)
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.chipBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
