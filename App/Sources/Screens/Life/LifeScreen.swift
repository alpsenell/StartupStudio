import SwiftUI
import TycoonEngine

/// The Life tab: the founder's home scene, wellbeing meters, work schedule,
/// personal money, weekend plan, and family. Everything here reads
/// `engine.state.life` and sends life actions; the engine owns the rules.
struct LifeScreen: View {
    let engine: GameEngine

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    // The home is the tab's face — it leads, like the office on HQ.
                    HomeCard(engine: engine)
                    LifeMetersCard(engine: engine)
                    WorkScheduleCard(engine: engine)
                    MoneyCard(engine: engine)
                    ActivitiesCard(engine: engine)
                    WeekendCard(engine: engine)
                    WeekendRecapCard(engine: engine)
                    PossessionsCard(engine: engine)
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
