import SwiftUI
import TycoonContent
import TycoonEngine

/// The independent ladder's ending, beside the IPO desk: the same gate
/// rows, the same button shape, the opposite promise. Nobody is bought
/// out and nothing is cashed in — the founder keeps the company, which is
/// the point — so the button carries the company rather than a number.
struct IndependenceCard: View {
    let engine: GameEngine

    @State private var confirming = false

    private var investors: InvestorState { engine.state.investors }

    var body: some View {
        let balance = engine.balance
        let config = balance.investors
        let state = engine.state
        let blocker = state.independenceBlocker(balance: balance)
        let ready = state.canStayIndependent(balance: balance)
        let signed = investors.equityRemaining < 100

        CardView("Staying independent", systemImage: "flag.checkered") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text(
                    signed
                        ? "This ending closed the day you signed. Somebody else owns a piece of it now."
                        : "Call it built, still owning every share. No bell, no buyer — the company stays yours and the run ends here."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 2) {
                    gateRow("You own all of it", met: !signed)
                    gateRow(
                        "\(config.independentProfitableQuarters) profitable quarters in a row "
                            + "(\(investors.profitableQuarters) so far)",
                        met: investors.profitableQuarters >= config.independentProfitableQuarters
                    )
                    gateRow(
                        "Reputation \(Int(config.independentMinReputation)) "
                            + "(\(Int(state.company.reputation.rounded())) now)",
                        met: state.company.reputation >= config.independentMinReputation
                    )
                    gateRow(
                        // A game year is 52 weeks of 7 days.
                        "\(max(1, config.independentMinDay / (GameState.daysPerWeek * 52))) years in "
                            + "(day \(state.day) of \(config.independentMinDay))",
                        met: state.day >= config.independentMinDay
                    )
                }

                Button {
                    confirming = true
                } label: {
                    Label("Call it built — Still yours", systemImage: "flag.checkered")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.positiveCash)
                .disabled(!ready)
                .accessibilityLabel(
                    ready
                        ? "Call it built. Ends the run with the company still yours."
                        : "Call it built. Not available: \(blocker ?? "")"
                )

                if let blocker {
                    Text(blocker)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .confirmationDialog(
            "Call \(state.company.name) built?",
            isPresented: $confirming,
            titleVisibility: .visible
        ) {
            Button("It's built, and it's mine") {
                engine.send(.declareIndependence)
            }
            Button("Not yet", role: .cancel) {}
        } message: {
            Text("This ends the run. You keep 100% of \(state.company.name); nobody buys anything.")
        }
    }

    private func gateRow(_ label: String, met: Bool) -> some View {
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
