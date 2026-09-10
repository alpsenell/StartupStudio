import PixelKit
import SwiftUI
import TycoonEngine

// MARK: K6 (home and rooms)

/// Where a tap in the home goes (iteration 15, meta.md §8).
///
/// The office has answered a tap since iteration 7; the home named twenty
/// fixtures and everybody in it and did nothing with any of them. This is
/// the home's `OfficeTapDestination`: every fixture opens the verb it
/// stands for, and every one of those verbs is an action or a sheet that
/// already exists. Nothing here is a second way to do anything — the Today
/// grid itself now lives in the sheet the founder's own figure opens, and
/// the Life tab's Today row opens the same sheet.
enum HomeTapDestination: Identifiable, Equatable {
    /// The founder: today's activities.
    case today
    /// Somebody in the house: their menu.
    case people(InteractionTarget)
    /// The bed: the work schedule.
    case work
    /// A same-day activity the fixture stands for, asked before it is done.
    case instant(InstantActivity)
    /// The suitcase: the sabbatical.
    case sabbatical
    /// The crib: the family's page.
    case family
    /// The laundry, the takeaway, the dead plant: the meters, with what the
    /// room is saying about them.
    case meters(String)
    /// A decor slot: the furnish sheet.
    case furnish
    /// The window: the city.
    case city

    var id: String {
        switch self {
        case .today: "today"
        case .people(let target): "people.\(target)"
        case .work: "work"
        case .instant(let activity): "instant.\(activity.rawValue)"
        case .sabbatical: "sabbatical"
        case .family: "family"
        case .meters(let line): "meters.\(line)"
        case .furnish: "furnish"
        case .city: "city"
        }
    }

    /// What a tap on `kind` means, as a pure function of the state, or
    /// `nil` for a thing that opens nothing (the lamp, the bookshelf) or
    /// somebody who is no longer there.
    static func destination(for kind: HomeHitRegion.Kind, state: GameState) -> HomeTapDestination? {
        let meters = state.life.meters
        switch kind {
        case .founder:
            return .today
        case .partner:
            return state.life.family.stage == .single ? nil : .people(.partner)
        case .child(let id):
            return state.life.family.children.contains { $0.id == id } ? .people(.child(id)) : nil
        case .decorSlot:
            return .furnish
        case .furniture(let fixture):
            switch fixture {
            case .bed: return .work
            case .couch, .television: return .instant(.cinema)
            case .fridge, .stove, .diningTable: return .instant(.restaurant)
            case .dumbbells, .yogaMat: return .instant(.gymSession)
            case .suitcase: return .sabbatical
            case .crib: return .family
            case .window: return .city
            case .laundry:
                return .meters("The laundry has been there since Tuesday. Mood \(Int(meters.mood.rounded())).")
            case .takeaway:
                return .meters(
                    "Takeaway again. Health \(Int(meters.health.rounded())), energy \(Int(meters.energy.rounded()))."
                )
            case .deadPlant:
                return .meters("The plant did not make it. Mood \(Int(meters.mood.rounded())).")
            case .armchair, .lamp, .bookshelf, .fireplace, .plant, .flowers:
                return nil
            }
        }
    }

    /// What VoiceOver says a tap does, after the scene has said what the
    /// thing is.
    static func hint(for kind: HomeHitRegion.Kind, state: GameState) -> String? {
        switch destination(for: kind, state: state) {
        case .today: "Opens today's activities"
        case .people: "Opens their menu"
        case .work: "Opens the work schedule"
        case .instant(let activity): "\(activity.displayName) tonight"
        case .sabbatical: "Opens the sabbatical"
        case .family: "Opens the family"
        case .meters: "Opens your meters"
        case .furnish: "Opens the furnish sheet"
        case .city: "Opens the city map"
        case nil: nil
        }
    }
}

// MARK: - The sheets a tap opens

/// Today's activities as a sheet: the grid that used to be the Life tab's
/// Today card, opened by the founder in the home and by the Today row.
struct TodaySheet: View {
    let engine: GameEngine

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HomeSheetStack(title: "Today") {
            ActivitiesGrid(engine: engine)
        }
        .presentationDetents([.medium, .large])
    }
}

/// What the room says about the founder — the laundry, the takeaway, the
/// dead plant — over the meters it is reading.
struct HomeMetersSheet: View {
    let engine: GameEngine
    let line: String

    var body: some View {
        HomeSheetStack(title: "How you are") {
            VStack(spacing: Theme.Spacing.lg) {
                PixelPanel {
                    Text(line)
                        .font(.callout)
                        .foregroundStyle(Theme.pixelInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                LifeMetersCard(engine: engine)
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// A pushed screen (the sabbatical, the family's page), in a sheet over the
/// home with a Done button.
struct HomeSheetStack<Content: View>: View {
    let title: String
    private let content: Content

    @Environment(\.dismiss) private var dismiss

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                content
                    .padding(Theme.Spacing.lg)
            }
            .background(Theme.screenBackground)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// A screen that owns its own scroll view, in a sheet with a Done button.
struct HomeScreenSheet<Content: View>: View {
    private let content: Content

    @Environment(\.dismiss) private var dismiss

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            content
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}

// MARK: end K6
