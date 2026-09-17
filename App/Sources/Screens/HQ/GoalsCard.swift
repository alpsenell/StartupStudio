import SwiftUI
import TycoonContent
import TycoonEngine

/// The chapter card on the HQ dashboard: which chapter the run is in, the
/// three things to do next with live progress bars, the perks earned so
/// far, and a teaser for what the next chapter is about.
///
/// Reads `engine.state.progression`, which `ProgressionSystem` refreshes
/// every day — so the card never re-evaluates a goal condition and never
/// disagrees with the engine.
struct GoalsCard: View {
    let engine: GameEngine

    private var progression: ProgressionState { engine.state.progression }

    var body: some View {
        // Nothing to show before the first tick (or with no goal catalog):
        // an empty card would be worse than none.
        if !progression.activeGoals.isEmpty || !progression.completedGoalIDs.isEmpty {
            CardView(chapterLabel, systemImage: "flag.checkered") {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    header

                    if progression.activeGoals.isEmpty {
                        Text("Every goal in this chapter is done. Nice.")
                            .emptySectionText()
                    } else {
                        VStack(spacing: Theme.Spacing.md) {
                            ForEach(progression.activeGoals) { goal in
                                GoalRow(goal: goal)
                            }
                        }
                    }

                    if !progression.earnedPerks.isEmpty {
                        perkStrip
                    }

                    if let teaser = nextChapterTeaser {
                        Divider()
                        Label(teaser, systemImage: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .accessibilityLabel("Next chapter: \(teaser)")
                    }

                    // The chapters so far, as a line (U2).
                    NavigationLink(value: StoryDestination.timeline) {
                        Label("Timeline", systemImage: "chevron.right")
                            .font(.footnote.weight(.semibold))
                    }
                    .buttonStyle(.borderless)
                    .accessibilityHint("Opens the company timeline")
                }
            }
        }
    }

    /// "CHAPTER 2 · LOFT" in the card header — and from the chapter where
    /// the ladders split, which one: "CHAPTER 3 · STUDIO · INDEPENDENT".
    private var chapterLabel: String {
        let base = "Chapter \(progression.chapter) · \(progression.chapterTitle)"
        guard let track = trackLabel else { return base }
        return base + " · " + track
    }

    /// The ladder's name once the founder has picked one, from the first
    /// chapter where it matters. Before then the question is still open
    /// and the header says nothing about it.
    private var trackLabel: String? {
        guard progression.chapter >= ProgressionState.firstSplitChapter else { return nil }
        return engine.state.declaredGoalTrack?.displayName
    }

    /// The question, while it is still open: from chapter 3 the goals
    /// depend on how the founder answers the next term sheet.
    private var undeclaredHint: String? {
        guard progression.chapter >= ProgressionState.firstSplitChapter,
              engine.state.declaredGoalTrack == nil
        else { return nil }
        return "Turn down a term sheet and this becomes the independent ladder. Sign one and it's the funded one, for good."
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(chapterProgressText)
                    .font(Theme.Typography.number(.subheadline))
                    .contentTransition(.numericText())
                    .animation(Theme.Motion.emphatic, value: chapterDone)
                Spacer()
                Text("\(progression.completedGoalIDs.count) done")
                    .font(Theme.Typography.number(.caption, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            if let undeclaredHint {
                Text(undeclaredHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(headerAccessibilityLabel)
    }

    private var headerAccessibilityLabel: String {
        var label = "Chapter \(progression.chapter), \(progression.chapterTitle)"
        if let trackLabel {
            label += ", \(trackLabel.lowercased()) ladder"
        }
        label += ". \(chapterDone) of \(chapterTotal) goals in this chapter finished, "
        label += "\(progression.completedGoalIDs.count) in the whole run."
        if let undeclaredHint {
            label += " \(undeclaredHint)"
        }
        return label
    }

    private var chapterProgressText: String {
        chapterTotal > 0 ? "\(chapterDone) of \(chapterTotal) this chapter" : ""
    }

    /// The chapter's goals on the ladder the run is on — six either way.
    private var chapterGoals: [GoalDef] {
        engine.content.goals(inChapter: progression.chapter, track: engine.state.goalTrack)
    }

    private var chapterDone: Int {
        chapterGoals.count { progression.completedGoalIDs.contains($0.id) }
    }

    private var chapterTotal: Int { chapterGoals.count }

    /// Only teased while there is a next chapter to reach, in the voice of
    /// the ladder the founder has chosen. The epilogue chapter is never
    /// teased ahead: it opens by playing past an ending, not by finishing
    /// goals, so chapter 5 reads exactly as it did before it existed.
    private var nextChapterTeaser: String? {
        let next = progression.chapter + 1
        guard next <= ProgressionState.chapterCount || engine.state.epilogue != nil else { return nil }
        guard engine.content.goals(inChapter: next).isEmpty == false else { return nil }
        let teaser = ChapterDef.teaser(for: next, track: engine.state.declaredGoalTrack)
        return teaser.isEmpty ? nil : teaser
    }

    private var perkStrip: some View {
        // 1–5 perks over the whole run; a plain wrapping row reads fine.
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(progression.earnedPerks, id: \.rawValue) { perk in
                Label(perk.displayName, systemImage: perk.systemImageName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, 3)
                    .background(Theme.chipBackground, in: Capsule())
                    .accessibilityLabel("\(perk.displayName) perk: \(perk.blurb)")
            }
        }
    }
}

// MARK: - One goal

/// A single goal: title, one-line detail, and a bar that fills as the run
/// gets closer to it.
private struct GoalRow: View {
    let goal: GoalProgress

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                Text(goal.title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Spacer(minLength: Theme.Spacing.xs)
                Text(valueLabel)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            if !goal.detail.isEmpty {
                Text(goal.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ProgressView(value: goal.fraction)
                .tint(goal.fraction >= 1 ? Theme.positiveCash : Theme.accent)
                .animation(Theme.Motion.valueChange, value: goal.fraction)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(goal.title). \(goal.detail)")
        .accessibilityValue("\(Int((goal.fraction * 100).rounded())) percent, \(valueLabel)")
    }

    /// A single-step goal ("move into the loft") reads as a state, not a
    /// count — "1 / 1" would be noise.
    private var valueLabel: String {
        goal.target <= 1 ? (goal.fraction >= 1 ? "Done" : "Not yet") : goal.countLabel
    }
}
