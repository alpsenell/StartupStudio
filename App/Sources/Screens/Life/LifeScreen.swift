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
                    WeekendCard(engine: engine)
                    FamilyCard(engine: engine)
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.screenBackground)
            .navigationTitle("Life")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
