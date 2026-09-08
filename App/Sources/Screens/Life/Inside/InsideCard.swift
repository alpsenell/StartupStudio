import PixelKit
import SwiftUI
import TycoonEngine

/// Iteration 11, wave two — W4. The Life tab's line about all this, in the
/// You section.
///
/// Nothing at all until a court has sent the founder down, and then three
/// states: inside (the days, and the door back into the room), on the run
/// (a fact, and a case with no date on it) and out (what the weeks came
/// to, and who came out of them with you).
struct InsideCard: View {
    let engine: GameEngine
    /// Pushes the release sheet — the caretaker's report, read as a
    /// release rather than as a postcard.
    var onOpen: () -> Void

    private var prison: PrisonState? { engine.state.prison }

    var body: some View {
        if let prison {
            CardView("Inside", systemImage: "building.columns.fill") {
                if prison.isInside {
                    serving(prison)
                } else if prison.onTheRun {
                    onTheRun(prison)
                } else {
                    out(prison)
                }
            }
        } else {
            // Nothing to show, and one job to do: `-autoInside` is sent
            // from here as well as from the root, because the root's task
            // can start before the fixture's engine is in the session and
            // this one cannot — the Life tab is built out of that engine.
            // A one-point invisible label rather than a `Color.clear`:
            // SwiftUI does not always run a task attached to a shape that
            // draws nothing, and this pass has to be able to start the
            // sentence from a surface that is definitely on screen.
            Text(verbatim: " ")
                .font(.system(size: 1))
                .opacity(0.01)
                .frame(height: 1)
                .task {
                    #if DEBUG
                    await InsideDebug.startIfAsked(current: { engine })
                    #endif
                }
        }
    }

    // MARK: - Serving

    @ViewBuilder
    private func serving(_ prison: PrisonState) -> some View {
        let left = prison.daysLeft(from: engine.state.day)
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("\(left) day\(left == 1 ? "" : "s") left of \(prison.sentenceWeeks) week\(prison.sentenceWeeks == 1 ? "" : "s").")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
            ProgressView(value: prison.progress(on: engine.state.day))
                .tint(Theme.accent)
            Text(prison.log.last?.text ?? "A landing, a door, and somebody on the top bunk.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - At large

    @ViewBuilder
    private func onTheRun(_ prison: PrisonState) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Label("On the run", systemImage: "figure.run")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.warning)
            Text("You went over the wall on day \(prison.sinceDay + prison.daysServed(on: engine.state.day)). There is a charge on the record with no date against it, and there is not going to be one.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Out

    @ViewBuilder
    private func out(_ prison: PrisonState) -> some View {
        let weeks = max(1, prison.daysServed(on: prison.releasedDay ?? engine.state.day) / 7)
        let heading = Prison.releaseHeading(prison.report, weeksServed: weeks)
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(heading.0)
                .font(.subheadline.weight(.semibold))
            Text(heading.1)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Theme.Spacing.lg) {
                stat("Library", "\(prison.libraryDays)")
                stat("On file", "\(prison.infractions)")
                stat(prison.paroleGranted ? "Paroled" : "Served", prison.paroleGranted ? "yes" : "all of it")
            }
            Button("The weeks, in order", systemImage: "list.bullet.rectangle") { onOpen() }
                .buttonStyle(.pressable)
                .font(.footnote.weight(.semibold))
        }
    }

    private func stat(_ name: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(Theme.Typography.number(.subheadline, weight: .semibold))
            Text(name)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

/// The release sheet: the caretaker's report, headed the way a release is
/// headed, with the log of the weeks under it.
///
/// This is the "inside" variant the brief asks for. The numbers are
/// `SabbaticalReport`'s — the same report the caretaker fills in on a
/// holiday, because the caretaker did the same job — but nothing about the
/// page says "welcome back". `Prison.releaseHeading` — which `SabbaticalSystem`'s W4
/// region calls `prisonReportHeading` — writes the two lines at the top.
struct InsideReleaseScreen: View {
    let engine: GameEngine

    private var prison: PrisonState? { engine.state.prison }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                if let prison {
                    headingCard(prison)
                    if let report = prison.report {
                        companyCard(report)
                    }
                    logCard(prison)
                    cellmateCard(prison)
                } else {
                    ContentUnavailableView(
                        "Nothing to read",
                        systemImage: "doc.text",
                        description: Text("You have never been inside.")
                    )
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.screenBackground)
        .navigationTitle("Time served")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func headingCard(_ prison: PrisonState) -> some View {
        let weeks = max(1, prison.daysServed(on: prison.releasedDay ?? engine.state.day) / 7)
        let heading = Prison.releaseHeading(prison.report, weeksServed: weeks)
        return PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                PixelText(
                    text: String(localized: "RELEASED", comment: "Pixel-font heading on the sheet the founder reads on the way out of a prison sentence. Uppercase A-Z only — the bitmap font has no accents."),
                    scale: 2,
                    color: Theme.pixelInk
                )
                Text(heading.0)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                Text(heading.1)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Divider()
                HStack(spacing: Theme.Spacing.lg) {
                    stat("Days", "\(prison.daysServed(on: prison.releasedDay ?? engine.state.day))")
                    stat("Library", "\(prison.libraryDays)")
                    stat("Yard", "\(prison.yardDays)")
                    stat("On file", "\(prison.infractions)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func companyCard(_ report: SabbaticalReport) -> some View {
        CardView("What \(report.caretakerName) did with it", systemImage: "key.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                row("Cash", from: report.opening.cash.money, to: report.closing.cash.money)
                row("On payroll", from: "\(report.opening.headcount)", to: "\(report.closing.headcount)")
                row("On the market", from: "\(report.opening.live)", to: "\(report.closing.live)")
                if !report.shipped.isEmpty {
                    Text("Shipped: \(report.shipped.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !report.lost.isEmpty {
                    Text("Gone: \(report.lost.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(Theme.negativeCash)
                }
            }
        }
    }

    private func logCard(_ prison: PrisonState) -> some View {
        CardView("The weeks", systemImage: "calendar") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                ForEach(prison.log) { entry in
                    HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                        Text("d\(entry.day)")
                            .font(Theme.Typography.number(.caption2))
                            .foregroundStyle(.tertiary)
                            .frame(width: 40, alignment: .leading)
                        Text(entry.text)
                            .font(.caption)
                            .foregroundStyle(entry.isIncident ? .primary : .secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cellmateCard(_ prison: PrisonState) -> some View {
        if !prison.cellmateName.isEmpty {
            CardView("Who came out with you", systemImage: "person.2.fill") {
                HStack(spacing: Theme.Spacing.md) {
                    PixelPortrait(seed: prison.cellmateSeed, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(prison.cellmateName)
                            .font(.subheadline.weight(.semibold))
                        Text("In your address book at \(Int(prison.cellmateBond.rounded())) rapport. He has a phone and no job.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func stat(_ name: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(Theme.Typography.number(.subheadline, weight: .semibold))
            Text(name)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func row(_ name: String, from: String, to: String) -> some View {
        HStack {
            Text(name)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer(minLength: Theme.Spacing.sm)
            Text("\(from) → \(to)")
                .font(Theme.Typography.number(.footnote, weight: .semibold))
        }
    }
}
