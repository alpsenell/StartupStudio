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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
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
        }
    }
}
