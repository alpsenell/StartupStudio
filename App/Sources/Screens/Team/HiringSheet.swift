import SwiftUI
import TycoonContent
import TycoonEngine

/// The hiring sheet: one card per candidate in the pool — portrait, a line
/// in their own voice, skills, salary, the trait their CV admits to, and
/// the one it doesn't until you interview them.
///
/// Hiring is blocked at the office tier's headcount cap; the engine
/// enforces it, the UI explains it.
struct HiringSheet: View {
    let engine: GameEngine

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    // MARK: J2 (record)
                    // One line: what recruiters hear when they ring the
                    // people who used to work for you. Nothing at all for a
                    // founder with a clean name and nobody vouching.
                    if standingName.score > 0 || standingName.vouching > 0 {
                        standingLine
                    }
                    // MARK: end J2
                    if candidates.isEmpty {
                        emptyState
                    } else {
                        ForEach(candidates) { candidate in
                            CandidateCard(
                                engine: engine,
                                candidate: candidate,
                                atCap: atCap,
                                interviewed: engine.state.progression
                                    .interviewedCandidateIDs.contains(candidate.id),
                                interviewBlocker: interviewBlocker,
                                departmentActive: candidate.role.department.map {
                                    engine.state.hasDepartment($0)
                                } ?? false,
                                // MARK: J2 (record)
                                standingAsk: engine.state.standingAsk(
                                    for: candidate, balance: engine.balance
                                ),
                                standingRefuses: engine.state.standingRefuses(
                                    candidate.id, balance: engine.balance
                                )
                                // MARK: end J2
                            )
                        }
                        if atCap {
                            capFooter
                        }
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.screenBackground)
            .navigationTitle("Hiring")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var candidates: [Candidate] {
        engine.state.candidatePool
    }

    // MARK: J2 (record)

    private var standingName: StandingName {
        engine.state.standingName(balance: engine.balance)
    }

    /// `YOUR NAME: +14% ON ASKS · 2 ALUMNI VOUCH`, and what it means.
    private var standingLine: some View {
        let name = standingName
        let refuses = name.refuses
        return VStack(alignment: .leading, spacing: 2) {
            Text(FounderStanding.nameLineText(name))
                .font(Theme.Typography.number(.caption, weight: .bold))
                .foregroundStyle(name.score > 0 ? Theme.warning : Theme.positiveCash)
            Text(
                refuses
                    ? "Recruiters ring the people who used to work for you. The best of them already did."
                    : name.score > 0
                        ? "Recruiters ring the people who used to work for you. Every ask below has heard."
                        : "Recruiters ring the people who used to work for you. It goes well."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: end J2

    private var headcountCap: Int {
        engine.balance.office(engine.state.company.officeTier).headcountCap
    }

    private var atCap: Bool {
        engine.state.headcount >= headcountCap
    }

    /// Why no interview can happen right now, mirroring `HiringSystem`'s
    /// gates so the button explains itself instead of doing nothing.
    private var interviewBlocker: String? {
        let state = engine.state
        if state.life.isAway(day: state.day) {
            return "You're away — \(state.life.awayReason?.lowercased() ?? "not in the office")"
        }
        if state.progression.lastInterviewDay == state.day {
            return "One interview a day. You do have a company to run."
        }
        return nil
    }

    private var emptyState: some View {
        let refresh = max(1, engine.balance.candidateRefreshDays)
        let days = refresh - (engine.state.day % refresh)
        return ContentUnavailableView(
            "No candidates right now",
            systemImage: "person.2.slash",
            description: Text(
                days == refresh
                    ? "A new batch arrives today."
                    : "The next batch arrives in \(days) day\(days == 1 ? "" : "s")."
            )
        )
        .padding(.top, Theme.Spacing.xl)
    }

    /// Why every Hire button is disabled. Copy names the current tier so it
    /// stays true after the garage era.
    private var capFooter: some View {
        let tierName = engine.state.company.officeTier.displayName.lowercased()
        let next = engine.state.company.officeTier.next?.displayName
        return Text(
            "Your \(tierName) only fits \(headcountCap) people."
                + (next.map { " Move to the \($0.lowercased()) from the HQ tab to hire more." } ?? "")
        )
        .font(.footnote)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }
}

// MARK: - Candidate card

private struct CandidateCard: View {
    let engine: GameEngine
    let candidate: Candidate
    let atCap: Bool
    /// Whether the founder has spent a day with this person.
    let interviewed: Bool

    /// The roster's best on each skill, for the tick on the bars.
    private var rosterBest: SkillSet {
        let people = engine.state.employees
        return SkillSet(
            coding: people.map(\.skills.coding).max() ?? 0,
            design: people.map(\.skills.design).max() ?? 0,
            marketing: people.map(\.skills.marketing).max() ?? 0
        )
    }
    /// Why an interview can't happen right now, if it can't.
    let interviewBlocker: String?
    /// Whether the candidate's department (if their role has one) is
    /// already staffed — flips the hint from "forms" to "joins".
    let departmentActive: Bool
    // MARK: J2 (record)
    /// What they ask once they have heard about the founder — the number
    /// `EmployeeSystem.hire` pays. The rolled salary at a clean name.
    let standingAsk: Int
    /// The best CV on the desk, past the line: they will not come in.
    let standingRefuses: Bool
    // MARK: end J2

    @State private var confirmingPass = false

    private var traits: [String] { candidate.traits }

    /// A line in their own voice: WS-B's dialogue when it has one, the
    /// first trait's authored bio otherwise.
    private var bio: String? {
        if let line = engine.content.dialogue.line(
            for: traits, mood: 70, context: .hired, seed: candidate.appearanceSeed
        ) {
            return line
        }
        return traits.first
            .flatMap { id in engine.content.traits.first { $0.id == id } }?
            .bio
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.md) {
                PixelPortrait(seed: candidate.appearanceSeed)

                VStack(alignment: .leading, spacing: 2) {
                    // Role is the headline: who they are, then what they cost.
                    HStack(spacing: Theme.Spacing.sm) {
                        Text(candidate.name)
                            .font(.system(.headline, design: .rounded))
                            .lineLimit(1)
                        RoleBadge(role: candidate.role, prominent: true)
                    }
                    // MARK: J2 (record) — the ask, name and all.
                    Text(
                        standingAsk == candidate.weeklySalary
                            ? "\(candidate.weeklySalary.money)/wk"
                            : "\(standingAsk.money)/wk · was \(candidate.weeklySalary.money)"
                    )
                    .font(Theme.Typography.number(.caption, weight: .regular))
                    .foregroundStyle(standingAsk == candidate.weeklySalary ? .secondary : Theme.warning)
                    // MARK: end J2
                }
                .accessibilityElement(children: .combine)

                Spacer(minLength: Theme.Spacing.sm)
            }

            if let bio {
                Text("\u{201C}\(bio)\u{201D}")
                    .font(.subheadline)
                    .italic()
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            SkillBars(skills: candidate.skills, reference: rosterBest)

            // The CV admits to one trait. The other takes a day of your
            // time to find out.
            TraitChipRow(
                traits: traits,
                content: engine.content,
                revealedCount: interviewed ? traits.count : 1
            )

            if let hint = departmentHint {
                Label(hint, systemImage: "building.columns")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !interviewed {
                interviewButton
            }

            HStack(spacing: Theme.Spacing.sm) {
                Button {
                    engine.send(.hire(candidateID: candidate.id))
                } label: {
                    Label("Hire", systemImage: "person.badge.plus")
                        .font(.system(.headline, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.xs)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                // MARK: J2 (record) — a refusal disables the hire too.
                .disabled(atCap || standingRefuses)
                .accessibilityLabel(
                    "Hire \(candidate.name), \(candidate.role.displayName), "
                        + "for \(standingAsk.money) per week"
                )
                // MARK: end J2

                Button {
                    confirmingPass = true
                } label: {
                    Text("Pass")
                        .font(.system(.headline, design: .rounded))
                        .padding(.vertical, Theme.Spacing.xs)
                        .padding(.horizontal, Theme.Spacing.sm)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Pass on \(candidate.name)")
            }
            // MARK: J2 (record)
            // Rule 7: the refused hire says why. Before an interview the
            // interview row already says it.
            if standingRefuses && interviewed {
                Text(FounderStanding.refusalLine)
                    .font(.caption)
                    .foregroundStyle(Theme.warning)
            }
            // MARK: end J2
        }
        .cardStyle()
        .confirmationDialog(
            "Pass on \(candidate.name)?",
            isPresented: $confirmingPass,
            titleVisibility: .visible
        ) {
            Button("Pass", role: .destructive) {
                engine.send(.passOnCandidate(candidateID: candidate.id))
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They leave the pool. A new batch shows up every two weeks.")
        }
    }

    private var interviewButton: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Button {
                engine.send(.interviewCandidate(candidateID: candidate.id))
            } label: {
                Label("Interview — costs you a day", systemImage: "bubble.left.and.bubble.right")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            // MARK: J2 (record) — the refusal is a blocker with a reason.
            .disabled(interviewBlocker != nil || standingRefuses)
            .accessibilityLabel(
                standingRefuses
                    ? "\(candidate.name) will not come in. \(FounderStanding.refusalLine)"
                    : "Interview \(candidate.name). Reveals the trait their CV left out, "
                        + "and costs a day of your energy."
            )

            Text(
                standingRefuses
                    ? FounderStanding.refusalLine
                    : interviewBlocker ?? "Reveals the trait their CV left out."
            )
            .font(.caption)
            .foregroundStyle(interviewBlocker == nil && !standingRefuses ? .secondary : Theme.warning)
            // MARK: end J2
        }
    }

    /// "Hiring a lawyer forms your Legal department" — only for roles that
    /// belong to a department.
    private var departmentHint: String? {
        guard let department = candidate.role.department else { return nil }
        return departmentActive
            ? "Joins your \(department.cardTitle) department."
            : "Hiring \(candidate.role.hiringNoun) forms your \(department.cardTitle) department."
    }
}
