import SwiftUI
import TycoonEngine

/// The hiring sheet: one card per candidate in the pool (portrait, skills,
/// salary, Hire button). Hiring is blocked at the office tier's headcount
/// cap; the engine enforces it, the UI explains it.
struct HiringSheet: View {
    let engine: GameEngine

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    if candidates.isEmpty {
                        emptyState
                    } else {
                        ForEach(candidates) { candidate in
                            CandidateCard(
                                candidate: candidate,
                                atCap: atCap,
                                departmentActive: candidate.role.department.map {
                                    engine.state.hasDepartment($0)
                                } ?? false
                            ) {
                                engine.send(.hire(candidateID: candidate.id))
                            }
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

    private var headcountCap: Int {
        engine.balance.office(engine.state.company.officeTier).headcountCap
    }

    private var atCap: Bool {
        engine.state.headcount >= headcountCap
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No candidates right now",
            systemImage: "person.2.slash",
            description: Text("A new batch shows up every two weeks.")
        )
        .padding(.top, Theme.Spacing.xl)
    }

    /// Why every Hire button is disabled. Copy names the current tier so it
    /// stays true after the garage era.
    private var capFooter: some View {
        let tierName = engine.state.company.officeTier.displayName.lowercased()
        return Text("Your \(tierName) only fits \(headcountCap) people. Upgrade coming soon.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
    }
}

// MARK: - Candidate card

private struct CandidateCard: View {
    let candidate: Candidate
    let atCap: Bool
    /// Whether the candidate's department (if their role has one) is
    /// already staffed — flips the hint from "forms" to "joins".
    let departmentActive: Bool
    let hire: () -> Void

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
                    Text("\(candidate.weeklySalary.money)/wk")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)

                Spacer(minLength: Theme.Spacing.sm)
            }

            SkillBars(skills: candidate.skills)

            if let hint = departmentHint {
                Label(hint, systemImage: "building.columns")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button(action: hire) {
                Label("Hire", systemImage: "person.badge.plus")
                    .font(.system(.headline, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.xs)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .disabled(atCap)
            .accessibilityLabel("Hire \(candidate.name), \(candidate.role.displayName), for \(candidate.weeklySalary.money) per week")
        }
        .cardStyle()
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
