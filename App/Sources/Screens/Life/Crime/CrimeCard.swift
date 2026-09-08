import SwiftUI
import TycoonEngine

/// Iteration 11 — N1. The Life tab's entry to the darker half of the
/// founder's life, in the You section under the sabbatical.
///
/// Three states, because the feature has three: a founder who has never
/// done anything (the pitch and the door), a founder with a record (the
/// needle, the last thing they did, and how cold it is getting), and a
/// founder with a hearing on the books (the clock, and the two things
/// they can do before it).
struct CrimeCard: View {
    let engine: GameEngine
    /// Pushes the record.
    var onOpen: () -> Void

    var body: some View {
        let state = engine.state
        CardView("The other ledger", systemImage: "scalemass.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                if let pending = state.crime.pendingCase {
                    pendingCase(pending, state: state)
                } else if state.crime.record.isEmpty {
                    clean
                } else {
                    record(state)
                }

                Button(
                    state.crime.pendingCase == nil ? "Open the ledger" : "Prepare",
                    systemImage: "folder.fill.badge.person.crop"
                ) { onOpen() }
                    .buttonStyle(.pressable)
                    .font(.footnote.weight(.semibold))
            }
        }
        // The screenshot pass runs from the card, not the route: it
        // commits, confesses, waits for the listing and then pushes the
        // ledger, which opens the room itself.
        .task {
            CrimeDebug.startIfAsked(engine: engine)
            await CrimeDebug.openWhenListed(engine: engine) { onOpen() }
        }
    }

    // MARK: - Nothing yet

    private var clean: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("There are six things you could do that would help enormously and that you should not do. They are all still available to you.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Nothing on the record.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - A record

    @ViewBuilder
    private func record(_ state: GameState) -> some View {
        CrimeNotorietyNeedle(notoriety: state.crime.notoriety)
        if let last = state.crime.record.last {
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                Image(systemName: last.offence.symbol)
                    .font(.footnote)
                    .foregroundStyle(Theme.warning)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(last.offence.displayName)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    Text(last.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        Text(exposureLine(state))
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// The one number that matters between offences: what the odds are
    /// this week, across everything still open, in the founder's words.
    private func exposureLine(_ state: GameState) -> String {
        let open = state.crime.openRecord
        guard !open.isEmpty else { return "Everything on the record has been answered for." }
        let hasLegal = state.knownDepartments.contains(.legal)
        // The chance at least one of them surfaces this week.
        let survive = open.reduce(1.0) { total, entry in
            total * (1 - Crime.discoveryChance(
                entry, notoriety: state.crime.notoriety, hasLegal: hasLegal,
                day: state.day, balance: engine.balance.crime
            ))
        }
        let percent = Int(((1 - survive) * 100).rounded())
        let legal = hasLegal ? " Legal is halving it." : ""
        return "\(open.count) thing\(open.count == 1 ? "" : "s") still open · about \(percent)% somebody notices this week.\(legal)"
    }

    // MARK: - A case

    @ViewBuilder
    private func pendingCase(_ legalCase: LegalCase, state: GameState) -> some View {
        let days = legalCase.daysToHearing(from: state.day)
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "building.columns.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.negativeCash)
                Text(legalCase.isFounderSuing
                    ? "Your suit is listed"
                    : "\(legalCase.offence?.chargeName.capitalizedFirstLetter ?? "The matter") is listed")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
            }
            Text(days == 0
                ? "The hearing is today."
                : "\(days) day\(days == 1 ? "" : "s") until the hearing.")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            if !legalCase.isFounderSuing {
                Text("They will take \(legalCase.settlementPrice.money) to make it go away. \(legalCase.lawyer.displayName) is representing you.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - The needle

/// Notoriety as a needle rather than a bar: it is a reading somebody else
/// takes of you, not a resource you spend.
struct CrimeNotorietyNeedle: View {
    let notoriety: Double

    private var tint: Color {
        switch notoriety {
        case ..<25: Theme.positiveCash
        case ..<60: Theme.warning
        default: Theme.negativeCash
        }
    }

    private var word: String {
        switch notoriety {
        case ..<10: "Nobody is looking"
        case ..<25: "A name that comes up"
        case ..<45: "Somebody is keeping a file"
        case ..<70: "You are a story waiting"
        default: "They are only deciding when"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("NOTORIETY")
                    .font(.caption2.weight(.bold))
                    .kerning(0.8)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text("\(Int(notoriety.rounded()))")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.chipBackground)
                    Capsule()
                        .fill(tint)
                        .frame(width: max(2, geometry.size.width * notoriety / 100))
                    Rectangle()
                        .fill(.primary.opacity(0.45))
                        .frame(width: 2, height: 14)
                        .offset(x: max(0, min(geometry.size.width - 2,
                            geometry.size.width * notoriety / 100 - 1)))
                }
            }
            .frame(height: 8)
            .animation(Theme.Motion.valueChange, value: notoriety)
            Text(word)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Notoriety \(Int(notoriety.rounded())) of 100. \(word).")
    }
}

extension String {
    /// "false accounting" → "False accounting". Not `capitalized`, which
    /// would also shout at the second word.
    var capitalizedFirstLetter: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
