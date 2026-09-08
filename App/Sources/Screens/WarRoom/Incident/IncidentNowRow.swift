import SwiftUI
import TycoonEngine

/// The Now card's incident row (iteration 10, M3).
///
/// Renders nothing on every ordinary day, so HQ's first card reads exactly
/// as it did. When something is on fire it is the way back into a room the
/// player put aside — the room presents itself the moment the incident is
/// raised, and this is what brings it back.
struct IncidentNowRow: View {
    let engine: GameEngine

    @Environment(AppRouter.self) private var router

    private var incident: IncidentState? { engine.state.incident }

    var body: some View {
        if let incident, let product = engine.state.product(id: incident.productID) {
            Button {
                Haptics.tap()
                Sounds.play(.tap)
                router.go(.incidentRoom)
            } label: {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(tint(incident.status))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(product.name) is \(incident.status.displayName.lowercased())")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(subtitle(incident))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: Theme.Spacing.sm)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressableRow)
            .accessibilityLabel(
                "\(product.name) is \(incident.status.displayName.lowercased()). \(subtitle(incident))"
            )
            .accessibilityHint("Opens the incident room")
        }
    }

    private func subtitle(_ incident: IncidentState) -> String {
        let users = incident.usersLost == 1 ? "1 user gone" : "\(incident.usersLost) users gone"
        let left = max(0, engine.balance.incidents.hoursPerIncident - incident.hoursSpent)
        return "\(users) · \(left)h left · back to the incident room"
    }

    private func tint(_ status: IncidentStatus) -> Color {
        switch status {
        case .red: Theme.negativeCash
        case .amber: Theme.warning
        case .green: Theme.positiveCash
        }
    }
}
