import SwiftUI
import TycoonEngine

// MARK: Iteration 7 — the custom company (R4)

/// What the custom page collects beyond the founder, the studio and the
/// origin: the seed (a code or a number, or nothing for random), the
/// difficulty (its rows move here on this path), and the three rules.
///
/// `startingCash` is `nil` while it is the difficulty's own; the stepper
/// writes a number the moment it moves, and *Reset* puts it back.
struct CustomChoices: Equatable {
    var seedText = ""
    var difficulty: Difficulty = .normal
    var rivalsEnabled = true
    var incumbentEnabled = true
    var startingCash: Int?

    static let cashRange = 10_000 ... 500_000
    static let cashStep = 10_000

    var entry: SeedEntry { SeedEntry.parse(seedText) }

    /// The rules as the engine takes them: `.standard` when nothing moved.
    func rules(defaultCash: Int) -> GameRules {
        GameRules(
            rivalsEnabled: rivalsEnabled,
            incumbentEnabled: incumbentEnabled,
            startingCash: startingCash.flatMap { $0 == defaultCash ? nil : $0 }
        )
    }

    /// The mode: custom when any rule is non-standard or the seed was
    /// typed; a custom page left at its defaults founds a standard,
    /// ranked company.
    func mode(defaultCash: Int) -> RunMode {
        !rules(defaultCash: defaultCash).isStandard || entry.isTyped ? .custom : .standard
    }

    /// Fills the page from a code: its seed, origin (returned for the
    /// Stakes page) and difficulty.
    mutating func prefill(with code: SeedCode) -> FoundingOrigin {
        seedText = code.encoded
        difficulty = code.difficulty
        return code.origin
    }
}

/// The Custom page: seed, stakes, the field, and the cash. Internal so
/// the snapshot suite can render it without driving the flow to it.
struct CustomStepContent: View {
    @Binding var choices: CustomChoices
    /// The difficulty's own starting cash, for the stepper's default and
    /// the reset line.
    let defaultCash: (Difficulty) -> Int

    private var cash: Int {
        choices.startingCash ?? defaultCash(choices.difficulty)
    }

    private var cashIsOverridden: Bool {
        choices.startingCash != nil && choices.startingCash != defaultCash(choices.difficulty)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            StepHeadline(
                title: "A company on your terms",
                detail: "A seed to replay, the stakes, the field, and the money on day one."
            )

            CardView("Seed", systemImage: "number") {
                SeedCodeField(text: $choices.seedText)
            }

            CardView("How hard should this be?", systemImage: "dial.medium.fill") {
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(Difficulty.allCases, id: \.self) { candidate in
                        StakesDifficultyRow(difficulty: candidate, isSelected: candidate == choices.difficulty) {
                            withAnimation(Theme.Motion.selection) { choices.difficulty = candidate }
                        }
                    }
                }
            }

            CardView("The field", systemImage: "flag.2.crossed.fill") {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    Toggle(isOn: $choices.rivalsEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Rivals")
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            Text("Named studios shipping into your topics, copying your hits and starting price wars.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .tint(Theme.accent)
                    Divider()
                    Toggle(isOn: $choices.incumbentEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("The incumbent")
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            Text("A deep-pocketed giant that founds into your two best markets once you are worth the trouble.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .tint(Theme.accent)
                }
            }

            CardView("Starting cash", systemImage: "dollarsign.circle.fill") {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    HStack(spacing: Theme.Spacing.md) {
                        PixelText(text: cash.money, scale: 3, color: cashIsOverridden ? Theme.pixelAccent : Theme.pixelInk)
                            .contentTransition(.numericText())
                            .animation(Theme.Motion.valueChange, value: cash)
                        Spacer(minLength: 0)
                        Stepper(
                            "Starting cash",
                            value: Binding(
                                get: { cash },
                                set: { choices.startingCash = min(max($0, CustomChoices.cashRange.lowerBound), CustomChoices.cashRange.upperBound) }
                            ),
                            in: CustomChoices.cashRange,
                            step: CustomChoices.cashStep
                        )
                        .labelsHidden()
                        .accessibilityLabel("Starting cash")
                        .accessibilityValue(cash.money)
                    }
                    if cashIsOverridden {
                        Button {
                            Haptics.tap()
                            withAnimation(Theme.Motion.selection) { choices.startingCash = nil }
                        } label: {
                            Text("Reset to \(choices.difficulty.displayName)'s \(defaultCash(choices.difficulty).money)")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.borderless)
                        .tint(Theme.accent)
                    } else {
                        Text("\(choices.difficulty.displayName)'s own. \(CustomChoices.cashRange.lowerBound.money) to \(CustomChoices.cashRange.upperBound.money), in \(CustomChoices.cashStep.money) steps.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                Image(systemName: "rosette")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                Text("A custom company earns achievements but does not post to leaderboards.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        }
        .padding(.top, Theme.Spacing.lg)
    }
}

/// The starting cash each difficulty's balance opens with, read once off
/// the bundled balance the engine plays. The page shows the number the
/// engine will use; nothing here changes it.
enum DifficultyCash {
    private static let bundled: BalanceConfig? = try? BalanceConfig.loadBundled()

    static func startingCash(for difficulty: Difficulty) -> Int {
        bundled?.adjusted(for: difficulty).startingCash ?? 50_000
    }
}
