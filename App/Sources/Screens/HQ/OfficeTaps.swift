import PixelKit
import SwiftUI
import TycoonEngine

/// Where a tap in the office goes.
///
/// The scene says what was touched (`OfficeHitRegion.Kind`); this says
/// what that means in the game, as a pure function of the state so a test
/// can pin the map: a person opens their page, the coffee machine its
/// menu, the whiteboard the build in flight (or the flow that starts one),
/// the door hiring, the founder's desk the work schedule.
enum OfficeTapDestination: Equatable, Identifiable {
    /// Somebody's page: morale, pay, the levers.
    case person(UUID)
    /// The coffee machine's menu: coffee with someone, or dinner for all.
    case coffee
    /// The build in flight.
    case product(UUID)
    /// Nothing in flight: start one.
    case newProduct
    /// The door: hiring.
    case hiring
    /// The founder's desk: the work schedule, theirs and the team's.
    case work

    var id: String {
        switch self {
        case .person(let id): "person.\(id.uuidString)"
        case .coffee: "coffee"
        case .product(let id): "product.\(id.uuidString)"
        case .newProduct: "newProduct"
        case .hiring: "hiring"
        case .work: "work"
        }
    }

    /// The destination for a region, or `nil` for a tap on somebody who
    /// has since left.
    static func destination(for kind: OfficeHitRegion.Kind, state: GameState) -> OfficeTapDestination? {
        switch kind {
        case .person(let id):
            guard let employee = state.employee(id: id) else { return nil }
            // The founder's levers are not in the manage sheet (it says so
            // itself); their desk is the work schedule, and so are they.
            return employee.isFounder ? .work : .person(id)
        case .coffeeMachine:
            return .coffee
        case .whiteboard:
            return state.productInDevelopment.map { .product($0.id) } ?? .newProduct
        case .door:
            return .hiring
        case .founderDesk:
            return .work
        }
    }

    /// What VoiceOver says a tap does, after the scene has said what the
    /// thing is.
    static func accessibilityHint(for kind: OfficeHitRegion.Kind, state: GameState) -> String? {
        switch destination(for: kind, state: state) {
        case .person: "Opens their page"
        case .coffee: "Coffee with someone, or dinner for the team"
        case .product(let id): "Opens \(state.product(id: id)?.name ?? "the build")"
        case .newProduct: "Starts a product"
        case .hiring: "Opens hiring"
        case .work: "Opens the work schedule"
        case nil: nil
        }
    }
}

// MARK: - The sheets a tap opens

/// The work schedule as a sheet — the card that carries both switches,
/// the founder's hours and the team's pace — so the founder's desk opens
/// it without leaving HQ.
struct WorkScheduleSheet: View {
    let engine: GameEngine

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                WorkScheduleCard(engine: engine)
                    .padding(Theme.Spacing.lg)
            }
            .background(Theme.screenBackground)
            .navigationTitle("Work")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// The product in development as a sheet, so the whiteboard opens it
/// where the player is instead of switching them to the Products tab.
struct ProductSheet: View {
    let engine: GameEngine
    let productID: UUID

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ProductDetailScreen(engine: engine, productID: productID)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}

// MARK: - The first-time hint

/// The one line under the office the first time: the scene is the
/// interface now, and nothing about a picture says "tap me". Dismisses
/// like the coach tips — by its own X, remembered in `GameSettings` — and
/// on the first tap that lands, which is the proof it was read.
struct OfficeTapHint: View {
    /// The `GameSettings.dismissedTips` key.
    static let tipID = "tip.office_tap"

    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.sm) {
            Image(systemName: "hand.tap.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 22)
            Text("Tap anyone — or the whiteboard, the coffee machine, the door.")
                .font(.footnote)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button {
                Haptics.tap()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.pressableRow)
            .accessibilityLabel("Dismiss tip")
        }
        .accessibilityElement(children: .contain)
    }
}
