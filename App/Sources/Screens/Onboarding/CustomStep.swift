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
    /// Iteration 8: the stake, 0–10.
    var stake = 0

    static let cashRange = 10_000 ... 500_000
    static let cashStep = 10_000

    var entry: SeedEntry { SeedEntry.parse(seedText) }

    /// The rules as the engine takes them: `.standard` when nothing moved.
    func rules(defaultCash: Int) -> GameRules {
        GameRules(
            rivalsEnabled: rivalsEnabled,
            incumbentEnabled: incumbentEnabled,
            startingCash: startingCash.flatMap { $0 == defaultCash ? nil : $0 },
            stake: stake
        )
    }

    /// The mode: custom when any rule is non-standard or the seed was
    /// typed; a custom page left at its defaults founds a standard,
    /// ranked company.
    func mode(defaultCash: Int) -> RunMode {
        // Iteration 8: a stake on its own stays ranked, the way a harder
        // difficulty does.
        let rules = rules(defaultCash: defaultCash)
        return (!rules.isStandard && !rules.isStakeOnly) || entry.isTyped ? .custom : .standard
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
    /// Iteration 8: the highest rung the ledger has opened (1 on a fresh
    /// install; a successful ending at stake n opens n + 1).
    var unlockedStake: Int = 1
    /// The ladder shows the rungs within reach; the rest fold away.
    @State private var showsWholeLadder = false

    private var cash: Int {
        choices.startingCash ?? defaultCash(choices.difficulty)
    }

    /// The open rungs, the next locked one, and any the player has lit.
    private var visibleStakes: [Stake] {
        guard !showsWholeLadder else { return StakeLadder.all }
        let reach = max(unlockedStake + 1, choices.stake)
        return StakeLadder.all.filter { $0.level <= reach }
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

            // Iteration 8: the ladder. Each rung keeps every rung below it.
            CardView("Stakes", systemImage: "flag.checkered") {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text(choices.stake == 0
                         ? "The same seed, one notch harder. A stake alone stays ranked."
                         : "Stake \(choices.stake): \(StakeLadder.stakes(upTo: choices.stake).map(\.title).joined(separator: ", ")).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(visibleStakes) { stake in
                        StakeRow(
                            stake: stake,
                            isOn: stake.level <= choices.stake,
                            isLocked: stake.level > unlockedStake
                        ) {
                            withAnimation(Theme.Motion.selection) {
                                choices.stake = stake.level == choices.stake ? stake.level - 1 : stake.level
                            }
                        }
                    }
                    if visibleStakes.count < StakeLadder.count {
                        Button {
                            Haptics.tap()
                            withAnimation(Theme.Motion.selection) { showsWholeLadder = true }
                        } label: {
                            Text("Show all \(StakeLadder.count) rungs")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.borderless)
                        .tint(Theme.accent)
                    }
                }
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
                Text("A stake alone stays ranked. Any other change earns achievements but does not post to leaderboards.")
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

/// One rung of the ladder: on, off, or padlocked until the rung below is
/// won. Tapping the highest lit rung turns it off; tapping a rung above
/// lights everything up to it.
private struct StakeRow: View {
    let stake: Stake
    let isOn: Bool
    let isLocked: Bool
    let action: () -> Void

    var body: some View {
        Button {
            guard !isLocked else { return }
            Haptics.tap()
            action()
        } label: {
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                PixelText(text: "\(stake.level)", scale: 2, color: isOn ? Theme.pixelAccent : Theme.pixelInk.opacity(0.4))
                    .frame(width: 22, alignment: .center)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(stake.title)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(isLocked ? .secondary : .primary)
                    Text(isLocked ? "Reach an ending at stake \(stake.level - 1)." : stake.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: isLocked ? "lock.fill" : (isOn ? "checkmark.circle.fill" : "circle"))
                    .font(.body)
                    .foregroundStyle(isLocked ? Color.secondary : (isOn ? Theme.accent : Color.secondary))
                    .padding(.top, 2)
            }
            .padding(.vertical, Theme.Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .accessibilityLabel("Stake \(stake.level), \(stake.title)")
        .accessibilityValue(isLocked ? "locked" : (isOn ? "on" : "off"))
        .accessibilityHint(isLocked ? "Reach an ending at stake \(stake.level - 1) to open it" : stake.detail)
    }
}
