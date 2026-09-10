import PixelKit
import SwiftUI
import TycoonEngine

// MARK: S4 (city)

/// The district panel's "who's here": the thing the last tap named (with
/// what a second tap does, as a button), the district's networking room
/// with its *Visit* row, and the rest of what stands here. The rivals are
/// the panel's own chip row above this, and the rent and the commute from
/// home are its pills and line below — this block adds, it replaces
/// nothing.
struct CityWhoIsHere: View {
    let engine: GameEngine
    let district: DistrictID
    let focused: CityHitTarget?
    let onOpen: (CityHitTarget) -> Void
    let onPlanWeekend: () -> Void

    private var style: DistrictStyle { DistrictStyle(rawValue: district.rawValue) ?? .oldTown }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            if let focused, focused.district == style, let row = focusRow(focused) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(row.title)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        Text(row.detail)
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    if let action = row.action {
                        Button(action) { onOpen(focused) }
                            .font(.caption.weight(.semibold))
                            .buttonStyle(.bordered)
                            .tint(Theme.accent)
                    }
                }
                .padding(Theme.Spacing.sm)
                .background(Theme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            visitRow

            Text(amenitiesLine)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: The room

    private var venue: NetworkingVenue? { NetworkingVenue(rawValue: style.venue.rawValue) }

    /// *Visit*: tonight's room if it is this one, else where tonight's
    /// room is, else how to get one opened — the consequence on the button.
    @ViewBuilder
    private var visitRow: some View {
        let state = engine.state
        let event = state.networking.pendingEvent
        let here = event != nil && event?.venue == venue
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Visit · \(venue?.displayName ?? "the room")")
                    .font(.caption.weight(.semibold))
                Text(visitDetail(event: event, here: here))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(here ? Theme.warning : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if here {
                Button("Go in") { onOpen(.venue(style)) }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
            } else if event == nil {
                Button("Plan a weekend") { onPlanWeekend() }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
            }
        }
    }

    private func visitDetail(event: NetworkingEvent?, here: Bool) -> String {
        let state = engine.state
        guard let event else {
            return "Nothing on tonight. A networking weekend opens one of the city's five rooms."
        }
        if here {
            let closes = max(0, event.expiresOnDay - state.day)
            return "Open tonight: \(event.contactIDs.count) people, \(event.conversationsLeft) conversation\(event.conversationsLeft == 1 ? "" : "s") left, closes in \(closes) day\(closes == 1 ? "" : "s")."
        }
        let there = CityVenueStyle(rawValue: event.venue.rawValue)?.district.displayName ?? "another district"
        return "Tonight's room is the \(event.venue.displayName), in \(there)."
    }

    // MARK: The rest

    private var amenitiesLine: String {
        let landmarks = engine.state.cityLandmarks(balance: engine.balance)
        var things: [String]
        switch style {
        case .suburbs:
            things = [landmarks.school ? "the school" : "a playground", "front gardens", "the hacker house"]
        case .midtown:
            things = ["the park and its pond", "a café", "the conference hotel"]
            if landmarks.hospital { things.append("the hospital") }
        case .techPark:
            things = ["the demo hall", "the car park", "the radio mast"]
        case .oldTown:
            things = ["the clock tower", "the co-working warehouse", "the quay"]
            if landmarks.courthouse { things.append("the courthouse") }
        case .downtown:
            things = ["the plaza and its fountain", "the rooftop terrace", "the river"]
        }
        if landmarks.formerOffice == style { things.append("your old office, to let") }
        return "Around here: " + things.joined(separator: " · ")
    }

    // MARK: The focused thing

    private struct FocusRow {
        var title: String
        var detail: String
        var action: String?
    }

    private func focusRow(_ target: CityHitTarget) -> FocusRow? {
        let state = engine.state
        switch target {
        case .district:
            return nil
        case .office:
            return FocusRow(
                title: "Your office",
                detail: "\(state.company.officeTier.displayName), \(state.city.ownership.isOwned ? "owned" : "renting").",
                action: "Open on HQ"
            )
        case .home:
            return FocusRow(
                title: "Your home",
                detail: "\(state.life.home.displayName) in \(district.displayName).",
                action: "Open on Life"
            )
        case .rival(_, let index):
            let rivals = state.cityRivals(in: district)
            guard rivals.indices.contains(index) else { return nil }
            let rival = rivals[index]
            return FocusRow(
                title: rival.name,
                detail: "Rival studio · \(rival.products.count) product\(rival.products.count == 1 ? "" : "s") on the market.",
                action: "Profile"
            )
        case .venue:
            let open = state.networking.pendingEvent?.venue == venue
            return FocusRow(
                title: venue?.displayName ?? "The room",
                detail: venue?.blurb ?? "",
                action: open ? "Go in" : nil
            )
        case .hospital:
            let stays = state.economy.hospitalizationDays.count
            return FocusRow(
                title: "The hospital",
                detail: "\(stays) stay\(stays == 1 ? "" : "s") on your record.",
                action: "See the doctor"
            )
        case .courthouse:
            let cases = state.crime.cases.count
            let pending = state.crime.cases.count(where: \.isPending)
            return FocusRow(
                title: "The courthouse",
                detail: "\(cases) case\(cases == 1 ? "" : "s") heard here\(pending > 0 ? ", \(pending) still open" : "").",
                action: "Your record"
            )
        case .school:
            let pupils = state.life.family.children.count {
                $0.stage(on: state.day, balance: engine.balance.childhood) == .school
            }
            return FocusRow(
                title: "The school",
                detail: "\(pupils) of yours here.",
                action: "The children"
            )
        case .formerOffice:
            let day = state.cityLastMoveDay.map { " You moved out on day \($0)." } ?? ""
            return FocusRow(
                title: "Your old office",
                detail: "The landlord has a TO LET board up.\(day)",
                action: nil
            )
        }
    }
}
// MARK: end S4
