import SwiftUI
import TycoonEngine

/// The "why did time stop?" strip under the HUD.
///
/// The engine records the events that auto-paused a tick in
/// `lastPauseEvents` and clears them the moment the player changes speed,
/// so this banner appears exactly when the clock stopped *because of
/// something* — never when the player paused on purpose — and disappears
/// the moment they answer it.
struct PauseBanner: View {
    let engine: GameEngine
    /// Deep-links the "Details" button to wherever the reason lives.
    var onRoute: ((Route) -> Void)?

    private var reasons: [GameEvent] { engine.lastPauseEvents }

    private var copy: EventCopy {
        EventCopy(state: engine.state, content: engine.content, balance: engine.balance)
    }

    /// The loudest of the events that stopped the clock leads the banner.
    private var headline: GameEvent? {
        reasons.max { lhs, rhs in
            severityRank(lhs.severity) < severityRank(rhs.severity)
        }
    }

    var body: some View {
        if engine.state.speed == .paused, let headline {
            let line = copy.line(for: headline)
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: line.icon)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(line.tint)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 1) {
                    Text(line.message)
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if reasons.count > 1 {
                        Text("+\(reasons.count - 1) more this day")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: Theme.Spacing.sm)

                if let route = route(for: headline), let onRoute {
                    Button("Details") {
                        Haptics.tap()
                        Sounds.play(.tap)
                        onRoute(route)
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.borderless)
                }

                Button {
                    Haptics.commit()
                    Sounds.play(.tap)
                    engine.setSpeed(.x1)
                } label: {
                    Label("Resume", systemImage: "play.fill")
                        .labelStyle(.iconOnly)
                        .font(.footnote.weight(.bold))
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.xs)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .accessibilityLabel("Resume time")
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)
            .background(line.tint.opacity(0.12))
            .overlay(alignment: .bottom) { Divider() }
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Time is paused: \(line.message)")
        }
    }

    /// Where "Details" should take the player for this reason.
    private func route(for event: GameEvent) -> Route? {
        switch event {
        case .reviewsIn(let productID, _, _),
             .shipped(let productID, _),
             .productOffMarket(let productID, _):
            .product(productID)
        case .marketBoom(let topicID, _), .marketCrash(let topicID, _):
            .marketReport(topicID: topicID)
        case .contractFailed, .contractDelivered, .contractCompleted:
            .contracts
        case .researchCompleted, .researchStarted:
            .research
        case .employeeQuit, .candidatesRefreshed:
            .hiring
        default:
            nil
        }
    }

    private func severityRank(_ severity: EventSeverity) -> Int {
        switch severity {
        case .quiet: 0
        case .info: 1
        case .notable: 2
        case .critical: 3
        }
    }
}
