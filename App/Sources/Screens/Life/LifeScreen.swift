import SwiftUI
import TycoonEngine

/// The Life tab: the founder's home scene, wellbeing meters, their own five
/// attributes, work schedule, personal money, weekend plan, the people they
/// know, and their family. Everything here reads `engine.state` and sends
/// life actions; the engine owns the rules.
struct LifeScreen: View {
    let engine: GameEngine

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    // The home is the tab's face — it leads, like the office on HQ.
                    HomeCard(engine: engine)
                    LifeMetersCard(engine: engine)
                    // What the founder is personally good at sits directly
                    // under the meters: both are "how much is a day of you
                    // worth", and the output line on the meters card is
                    // the sum of the two.
                    FounderSkillsCard(engine: engine)
                    WorkScheduleCard(engine: engine)
                    MoneyCard(engine: engine)
                    ActivitiesCard(engine: engine)
                    WeekendCard(engine: engine)
                    WeekendRecapCard(engine: engine)
                    // The networking floor and the address book. Placed
                    // after the weekend plan, which is what opens a room.
                    NetworkingCard(engine: engine)
                    PossessionsCard(engine: engine)
                    PartnerCard(engine: engine)
                    FamilyCard(engine: engine)
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
