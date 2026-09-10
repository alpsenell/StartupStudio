import SwiftUI
import TycoonEngine

// MARK: Iteration 15 — K5 (hand over the keys)

/// The gate on *Hand it to…*, read once so the Walking-away card and the
/// sheet agree: the engine's own `handOverBlocker`, never a copy.
struct HandOverGate: Equatable {
    let blocker: String?

    init(state: GameState, balance: BalanceConfig) {
        blocker = state.handOverBlocker(balance: balance)
    }

    var ready: Bool { blocker == nil }
}

/// *Hand it to…*: the second answer beside *Walk away*. Pick the person,
/// pick what you keep, read what it means — what you keep, what they
/// inherit, that the run goes unranked, that *Still yours* is shut to them
/// until they buy your stake back — and sign.
struct HandOverSheet: View {
    let engine: GameEngine
    var onClose: () -> Void = {}

    @Environment(\.gameSession) private var session
    @State private var pickedID: UUID?
    @State private var keptPercent = HandOverKeep.standard
    @State private var confirming = false

    /// The bitmap kicker. PixelFont has no lowercase and no accents.
    static let kicker = String(
        localized: "HAND OVER THE KEYS",
        comment: "Pixel-font headline on the hand-over sheet. Uppercase A-Z only — the bitmap font has no accents."
    )

    var body: some View {
        let state = engine.state
        let balance = engine.balance
        let successor = selected(state)
        let terms = successor.flatMap {
            state.handOverTerms(successorID: $0.id, keptPercent: keptPercent, balance: balance)
        }
        let blocker = blocker(state, successor: successor)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    header(state)
                    peopleCard(state)
                    keepCard(state)
                    if let terms {
                        termsCard(state, terms: terms, blocker: blocker)
                    } else if let blocker {
                        warning(blocker)
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Theme.screenBackground.ignoresSafeArea())
            .navigationTitle("Hand it over")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not yet", action: onClose)
                }
            }
        }
        .confirmationDialog(
            "Hand \(state.company.name) to \(terms?.successorName ?? "them")?",
            isPresented: $confirming,
            titleVisibility: .visible,
            presenting: terms
        ) { terms in
            Button("Hand over the keys") { handOver(terms) }
            Button("Not yet", role: .cancel) {}
        } message: { terms in
            Text(
                "You keep \(terms.keptEquity.oneDecimal)% and nothing else. From here you play as "
                    + "\(terms.successorName), and the run is unranked. This does not undo."
            )
        }
    }

    // MARK: - Pieces

    private func header(_ state: GameState) -> some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                PixelText(text: Self.kicker, scale: 3, color: Theme.pixelAccent, shadow: true)
                Text(
                    "Name who runs \(state.company.name) next and keep a slice of it. The company "
                        + "carries on — its products, its rivals, its case and its debts — and "
                        + "so do you, as them."
                )
                .font(.footnote)
                .foregroundStyle(Theme.pixelInk.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func peopleCard(_ state: GameState) -> some View {
        let people = state.handOverCandidates(balance: engine.balance)
        return CardView("Who takes it", systemImage: "key.fill") {
            VStack(spacing: Theme.Spacing.md) {
                ForEach(people.prefix(6)) { person in
                    let reason = state.handOverSuccessorBlocker(person, balance: engine.balance)
                    Button {
                        pickedID = person.id
                    } label: {
                        CaretakerRow(
                            employee: person,
                            tenureWeeks: state.tenureWeeks(person),
                            blocker: reason,
                            minBond: engine.balance.sabbatical.minBond,
                            isSelected: selected(state)?.id == person.id
                        )
                    }
                    .buttonStyle(.pressableRow)
                    .disabled(reason != nil)
                }
                Text(
                    "The same test as a caretaker: \(engine.balance.sabbatical.minTenureWeeks) weeks on "
                        + "the payroll and a bond of \(Int(engine.balance.sabbatical.minBond)) with you."
                )
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func keepCard(_ state: GameState) -> some View {
        let holding = state.investors.equityRemaining
        return CardView("What you keep", systemImage: "chart.pie.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("You hold \(holding.oneDecimal)% of the company. Keep part of that as a silent stake:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(HandOverKeep.percents, id: \.self) { percent in
                        let chosen = percent == keptPercent
                        Button {
                            keptPercent = percent
                        } label: {
                            VStack(spacing: 2) {
                                Text("\(percent)%")
                                    .font(.subheadline.weight(.bold))
                                Text("\((holding * Double(percent) / 100).oneDecimal)% of it")
                                    .font(.caption2)
                            }
                            .monospacedDigit()
                        }
                        .buttonStyle(PixelButtonStyle(fill: chosen ? Theme.pixelAccent : Theme.cardBackground))
                        .accessibilityLabel("Keep \(percent) percent of your stake")
                        .accessibilityAddTraits(chosen ? .isSelected : [])
                    }
                }
            }
        }
    }

    private func termsCard(_ state: GameState, terms: HandOverTerms, blocker: String?) -> some View {
        CardView("What it means", systemImage: "doc.text") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                term(
                    "You keep \(terms.keptEquity.oneDecimal)% — \(terms.keptValue.money) today. "
                        + "No seat, no vote, no salary."
                )
                term("The ledger writes you down as Walked away, with \(terms.outgoingNetWorth.money) behind you.")
                term(
                    "\(terms.successorName) holds \(terms.successorEquity.oneDecimal)%, draws "
                        + "\(terms.successorSalary.money) a week, and starts single in a studio flat "
                        + "with \(terms.successorWallet.money) in the wallet."
                )
                term("\(state.company.name) keeps its cash, products, rivals, case and debts.")
                term("The run becomes unranked. Nothing from here posts to a leaderboard.")
                term(
                    "Still yours is closed to \(terms.successorName) until they buy your stake back — "
                        + "\(terms.buybackPrice.money) today, on the cap table."
                )

                Button {
                    confirming = true
                } label: {
                    Text("Hand it to \(terms.successorName) — keep \(terms.keptPercent)%")
                        .font(.footnote.weight(.semibold))
                }
                .buttonStyle(PixelButtonStyle())
                .disabled(blocker != nil)
                .padding(.top, Theme.Spacing.xs)

                if let blocker {
                    warning(blocker)
                }
            }
        }
    }

    private func term(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
            Text("·")
                .font(.footnote.weight(.bold))
                .foregroundStyle(Theme.accent)
            Text(text)
                .font(.footnote)
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func warning(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(Theme.warning)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Plumbing

    /// The row the player picked, or the best person who passes — so the
    /// button is never dead on a sheet where somebody obviously qualifies.
    private func selected(_ state: GameState) -> Employee? {
        let people = state.handOverCandidates(balance: engine.balance)
        if let pickedID, let picked = people.first(where: { $0.id == pickedID }) {
            return picked
        }
        return people.first { state.handOverSuccessorBlocker($0, balance: engine.balance) == nil }
    }

    private func blocker(_ state: GameState, successor: Employee?) -> String? {
        if let reason = state.handOverBlocker(balance: engine.balance) { return reason }
        guard let successor else { return "Nobody here could take it yet." }
        return state.handOverSuccessorBlocker(successor, balance: engine.balance)
            .map { "\(successor.name): \($0)" }
    }

    /// Through the session when there is one, so the outgoing founder's
    /// line is written from the state before the keys change hands.
    private func handOver(_ terms: HandOverTerms) {
        let accepted: Bool = if let session {
            session.handOverKeys(successorID: terms.successorID, keptPercent: terms.keptPercent)
        } else {
            !engine.send(.handOverKeys(
                successorID: terms.successorID, keptPercent: terms.keptPercent,
                predecessorRunID: UUID()
            )).isEmpty
        }
        guard accepted else { return }
        Haptics.commit()
        onClose()
    }
}

/// The journal's line for `.keysHandedOver`, in the shape `EventCopy`
/// switches on.
enum HandOverCopy {
    static func line(
        state: GameState, successorID: UUID, keptEquity: Double, day: Int
    ) -> (icon: String, message: String, day: Int, tint: Color) {
        let heir = state.employee(id: successorID)?.name ?? "Your successor"
        let old = state.investors.rounds.last(where: \.isEmeritus)?.investorName
            ?? state.lineage?.predecessorFounderName
            ?? "The old founder"
        return (
            "key.fill",
            "\(heir) has the keys. \(old) kept \(keptEquity.oneDecimal)% and no seat.",
            day,
            Theme.accent
        )
    }
}

// MARK: end K5
