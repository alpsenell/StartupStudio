import PixelKit
import SwiftUI
import TycoonEngine

/// Iteration 9 — L6. The sheet the founder reads on the plane home: what
/// the caretaker started, shipped, hired and lost, the company's numbers
/// then and now, and the whole log.
///
/// Built like `WeeklyReportSheet` on purpose — a pixel-paper headline, then
/// ordinary cards — because this is the same kind of document: a week's
/// numbers, except somebody else wrote them.
struct SabbaticalReportSheet: View {
    let engine: GameEngine
    let report: SabbaticalReport

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    headline
                    numbers
                    whatHappened
                    if !report.log.isEmpty { log }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.screenBackground)
            .navigationTitle("You're back")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Headline

    private var headline: some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                PixelText(text: String(localized: "BACK", comment: "Pixel-font headline on the sabbatical return sheet: the founder is home. Uppercase A-Z only — the bitmap font has no accents."), scale: 3, color: Theme.pixelAccent, shadow: true)
                Text(report.headline)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.pixelInk)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(Theme.pixelInk.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        let days = "\(report.days) day\(report.days == 1 ? "" : "s") away"
        let paid = "\(report.cost.money) of your own money"
        if report.endedEarly, let reason = report.earlyReason {
            return "\(days) of \(report.weeks * 7) · \(paid) · \(reason)"
        }
        return "\(days) · \(paid) · \(report.caretakerName) had the keys"
    }

    // MARK: - Numbers

    private var numbers: some View {
        CardView("The company, then and now", systemImage: "chart.line.uptrend.xyaxis") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(alignment: .top, spacing: Theme.Spacing.xl) {
                    SabbaticalStat(
                        label: "Cash",
                        was: report.opening.cash.money,
                        now: report.closing.cash.money,
                        better: report.closing.cash >= report.opening.cash
                    )
                    SabbaticalStat(
                        label: "Morale",
                        was: "\(Int(report.opening.morale.rounded()))",
                        now: "\(Int(report.closing.morale.rounded()))",
                        better: report.closing.morale >= report.opening.morale
                    )
                    SabbaticalStat(
                        label: "Team",
                        was: "\(report.opening.headcount)",
                        now: "\(report.closing.headcount)",
                        better: report.closing.headcount >= report.opening.headcount
                    )
                    SabbaticalStat(
                        label: "Rep",
                        was: "\(Int(report.opening.reputation.rounded()))",
                        now: "\(Int(report.closing.reputation.rounded()))",
                        better: report.closing.reputation >= report.opening.reputation
                    )
                }
                Text(report.closing.cash >= report.opening.cash
                     ? "It made money without you in the building."
                     : "It burned \((report.opening.cash - report.closing.cash).money) while you were gone.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - What happened

    private var whatHappened: some View {
        CardView("What \(report.caretakerName) did", systemImage: "figure.walk.motion") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                ReportList(title: "Shipped", items: report.shipped, icon: "shippingbox.fill", tint: Theme.positiveCash)
                ReportList(title: "Started", items: report.started, icon: "hammer.fill", tint: Theme.accent)
                ReportList(title: "Hired", items: report.hired, icon: "person.badge.plus", tint: Theme.accent)
                ReportList(title: "Lost", items: report.lost, icon: "person.badge.minus", tint: Theme.negativeCash)
                if report.shipped.isEmpty, report.started.isEmpty,
                   report.hired.isEmpty, report.lost.isEmpty {
                    Text("Nothing. They kept the lights on and left the big calls to you, which is its own kind of answer.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Log

    private var log: some View {
        CardView("The log", systemImage: "list.bullet.rectangle") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                ForEach(report.log) { entry in
                    LogLine(entry: entry)
                }
            }
        }
    }
}

private struct ReportList: View {
    let title: String
    let items: [String]
    let icon: String
    let tint: Color

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Label(title, systemImage: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                ForEach(items, id: \.self) { item in
                    Text("· \(item)")
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }
}
