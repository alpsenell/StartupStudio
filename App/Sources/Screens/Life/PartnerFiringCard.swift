import SwiftUI
import TycoonEngine

// MARK: T1 (exits and joins)

/// The morning after the founder fired their partner with cause: a bag by
/// the door, and two answers with their price on the button. Draws nothing
/// at all while no such question is open, so the Life tab reads as it
/// always did.
struct PartnerFiringCard: View {
    let engine: GameEngine

    var body: some View {
        let state = engine.state
        if let firing = state.openPartnerFiring {
            let balance = engine.balance
            let first = firing.name.split(separator: " ").first.map(String.init) ?? firing.name
            let respondBy = firing.respondByDay(balance: balance) ?? state.day
            let left = max(0, respondBy - state.day)
            CardView("The bag by the door", systemImage: "suitcase.fill") {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("You fired \(first) for cause. They packed a bag last night and left it by the door. Affection \(Int(state.life.family.affection.rounded())).")
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                    answer(
                        "Pack a bag",
                        detail: "You end the marriage · the settlement follows",
                        fill: Theme.negativeCash,
                        packBag: true
                    )
                    answer(
                        "Stay and take it",
                        detail: "Affection −\(Int(balance.exits.partnerFiringStayAffection)) · \(first) won't work for you again",
                        fill: Theme.pixelAccent,
                        packBag: false
                    )
                    Text(left == 0 ? "Unanswered today, staying is the answer." : "Unanswered in \(left) day\(left == 1 ? "" : "s"), staying is the answer.")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(left <= 1 ? Theme.warning : .secondary)
                }
            }
        }
    }

    private func answer(_ label: String, detail: String, fill: Color, packBag: Bool) -> some View {
        Button {
            Haptics.tap()
            engine.send(.answerPartnerFiring(packBag: packBag))
        } label: {
            VStack(spacing: 2) {
                Text(label)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Text(detail)
                    .font(.caption2)
                    .opacity(0.9)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PixelButtonStyle(fill: fill))
    }
}

#if DEBUG
/// `-autoRoute t1-buyout|t1-earnout|t1-sellup|t1-dividend|t1-firing` with
/// `-autoFixture release-studio-day400`: the save dressed once, through the
/// engine (`.exitsDebugSeed`), when the tab the route lands on appears.
@MainActor
enum ExitsDebugLaunch {
    private static var seeded = false

    static func seedIfAsked(_ engine: GameEngine) {
        guard !seeded, let name = DebugLaunch.autoRouteName, name.hasPrefix("t1-") else { return }
        seeded = true
        engine.send(.exitsDebugSeed(scenario: String(name.dropFirst("t1-".count))))
    }
}
#endif

// MARK: end T1
