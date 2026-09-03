import SwiftUI
import TycoonEngine

/// The Life tab, in the order the founder's week runs: this week's
/// decisions first, then the people in it, then the money and the home,
/// then the founder's own sheet.
///
/// The home scene used to lead and the weekly cards sat fourth, sixth,
/// seventh and ninth in a twelve-card stack; now the week is the first
/// card and the rest is grouped under headers.
struct LifeScreen: View {
    let engine: GameEngine

    @Environment(AppRouter.self) private var router
    @State private var path: [LifeDestination] = []

    /// What Life can push. One case today; an enum rather than a
    /// `NavigationPath` so the deep link can ask "am I already there?".
    enum LifeDestination: Hashable {
        case agenda
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    // The fortnight leads: it is the only card that answers
                    // "what is coming" — everything under it answers "what
                    // is true now".
                    AgendaCard(
                        engine: engine,
                        onOpen: { path = [.agenda] },
                        onRoute: { router.go($0) }
                    )
                    ThisWeekCard(engine: engine)

                    BusinessSectionHeader(title: "This week", systemImage: "calendar")
                    ActivitiesCard(engine: engine)
                    WeekendCard(engine: engine)
                    WeekendRecapCard(engine: engine)
                    // The networking floor and the address book. Placed
                    // after the weekend plan, which is what opens a room.
                    NetworkingCard(engine: engine)

                    BusinessSectionHeader(title: "People", systemImage: "person.2.fill")
                    PartnerCard(engine: engine)
                    FamilyCard(engine: engine)

                    BusinessSectionHeader(title: "Money and home", systemImage: "house.fill")
                    MoneyCard(engine: engine)
                    HomeCard(engine: engine)
                    PossessionsCard(engine: engine)

                    BusinessSectionHeader(title: "You", systemImage: "person.fill")
                    FounderSkillsCard(engine: engine)
                    LifeMetersCard(engine: engine)
                }
                .padding(Theme.Spacing.lg)
            }
            // The HUD inset lives on the stack's root content (not on the
            // NavigationStack) so the root scrolls below it and any pushed
            // destination shows the navigation bar instead.
            .withTopHUD(engine: engine)
            .background(Theme.screenBackground)
            .navigationTitle("Life")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: LifeDestination.self) { destination in
                switch destination {
                case .agenda:
                    AgendaScreen(engine: engine)
                }
            }
            .onChange(of: router.pendingPush, initial: true) { _, _ in
                consumeRoute()
            }
        }
    }

    /// Deep links into this tab: `.agenda` pushes the fortnight, and
    /// `.life` — which the agenda's own diary rows send — means "the Life
    /// tab itself", so it pops back to the root.
    private func consumeRoute() {
        if router.take(.agenda) {
            path = [.agenda]
        } else if router.take(.life) {
            path = []
        }
    }
}
