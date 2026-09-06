import SwiftUI
import TycoonEngine

// MARK: Iteration 8 — scenarios

/// The Scenarios room: this week's featured one first, then the rest,
/// each with its stars and one button.
struct ScenariosSheet: View {
    let entries: [ScenarioEntry]
    let totalStars: Int
    var onPlay: (Scenario) -> Void = { _ in }
    var onClose: () -> Void = {}

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    HStack(spacing: Theme.Spacing.sm) {
                        PixelText(text: "\(totalStars) of \(entries.count * 3)", scale: 3, color: Theme.pixelAccent)
                        Text("stars")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(totalStars) of \(entries.count * 3) stars")
                    Text("A company already in a situation, an objective, and a clock. Three stars for doing it fast, or for the money left over. The featured one has a board this week.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(entries) { entry in
                        ScenarioRow(entry: entry) { onPlay(entry.scenario) }
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Theme.screenBackground.ignoresSafeArea())
            .navigationTitle("Scenarios")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onClose)
                }
            }
        }
    }
}

private struct ScenarioRow: View {
    let entry: ScenarioEntry
    let action: () -> Void

    var body: some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        if entry.isFeatured {
                            Text("THIS WEEK")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Theme.pixelAccent)
                        }
                        Text(entry.scenario.title)
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(Theme.pixelInk)
                    }
                    Spacer(minLength: 0)
                    StarRow(stars: entry.ledger?.bestStars ?? 0)
                }
                Text(entry.scenario.brief)
                    .font(.footnote)
                    .foregroundStyle(Theme.pixelInk.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                Label(entry.scenario.goal, systemImage: "flag.checkered")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.pixelInk)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    Haptics.tap()
                    Sounds.play(.tap)
                    action()
                } label: {
                    Label(buttonTitle, systemImage: "play.fill")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PixelButtonStyle())
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(entry.isFeatured ? "This week's scenario. " : "")\(entry.scenario.title). \(entry.scenario.brief) \(entry.scenario.goal) \(entry.ledger?.bestStars ?? 0) of 3 stars.")
    }

    private var buttonTitle: String {
        if entry.hasRunUnderWay { return "Continue" }
        return entry.ledger == nil ? "Play" : "Play again"
    }
}

/// Three stars, lit or not.
struct StarRow: View {
    let stars: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: index < stars ? "star.fill" : "star")
                    .font(.caption)
                    .foregroundStyle(index < stars ? Theme.pixelAccent : Theme.pixelInk.opacity(0.3))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stars) of 3 stars")
    }
}

/// The card a finished scenario hands back to the front door.
struct ScenarioResultSheet: View {
    let result: ScenarioResult
    var onClose: () -> Void = {}

    private var scenario: Scenario? { ScenarioCatalog.scenario(result.scenarioID) }

    var body: some View {
        NavigationStack {
            ScrollView {
                PixelPanel {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        PixelSectionTitle(title: scenario?.title ?? "Scenario")
                        HStack(spacing: Theme.Spacing.md) {
                            switch result.outcome {
                            case .won(let stars):
                                PixelText(text: "DONE", scale: 4, color: Theme.pixelAccent)
                                StarRow(stars: stars)
                            case .lost:
                                PixelText(text: "NOT THIS TIME", scale: 3, color: Theme.negativeCash)
                            }
                        }
                        Text(line)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(Theme.pixelInk)
                            .fixedSize(horizontal: false, vertical: true)
                        if case .won = result.outcome {
                            Label(result.featured ? "Sent to this week's board." : "Not this week's scenario, so no board — the stars are yours.",
                                  systemImage: result.featured ? "checkmark.seal.fill" : "star")
                                .font(.caption)
                                .foregroundStyle(result.featured ? Theme.positiveCash : Theme.pixelInk.opacity(0.7))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.screenBackground.ignoresSafeArea())
            .navigationTitle("Scenario")
            .navigationBarTitleDisplayMode(.inline)
            .presentationDetents([.medium, .large])
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onClose)
                }
            }
        }
    }

    private var line: String {
        guard let scenario else { return "" }
        switch (result.outcome, scenario.objective) {
        case (.won, .reachBy):
            return "\(scenario.goal) Done in \(result.daysUsed) of \(scenario.days) days, with \(result.cash.money) in the bank."
        case (.won, .holdUntil):
            return "\(scenario.goal) Held for \(scenario.days) days, with \(result.cash.money) in the bank."
        case (.lost, _):
            return "\(scenario.goal) It got away on day \(result.daysUsed)."
        }
    }
}
