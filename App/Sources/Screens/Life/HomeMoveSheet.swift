import PixelKit
import SwiftUI
import TycoonEngine

// MARK: K6 (home and rooms)

/// Where the founder lives (life.md §3): the five districts the city
/// already has, each with both of its prices printed side by side — the
/// rent as a share of the salary, and what the commute takes out of the
/// week — and the move priced on its own button.
///
/// The engine owns every number (`GameState.homeMoveQuotes`) and every
/// refusal; this sheet prints them and sends `.moveHome`.
struct HomeMoveSheet: View {
    let engine: GameEngine

    @Environment(\.dismiss) private var dismiss
    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// See `GameShell.shared`: read optionally, because SwiftUI
    /// updates this property for presented content before the
    /// environment is installed and the non-optional form traps there.
    private var shell: GameShell { injectedShell ?? .shared }

    var body: some View {
        let state = engine.state
        let quotes = state.homeMoveQuotes(balance: engine.balance)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    header(state)
                    ForEach(quotes) { quote in
                        row(quote)
                    }
                    Text(
                        "The office is in \(state.city.district.displayName). Move the office and the commute moves with it — the city map prints what it would do to yours."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.screenBackground)
            .navigationTitle("Where you live")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - The header

    private func header(_ state: GameState) -> some View {
        let rent = state.homeWeeklyRent(balance: engine.balance)
        return PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(alignment: .center, spacing: Theme.Spacing.md) {
                    PixelIconTile(systemImage: "house.fill", tint: Theme.accent, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        PixelText(
                            text: state.life.homeDistrict?.displayName ?? "No address",
                            scale: 2,
                            color: Theme.pixelInk
                        )
                        Text("\(state.life.home.displayName) · \(rent.money) a week")
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(Theme.pixelInk.opacity(0.7))
                    }
                }
                Text(summary(state))
                    .font(.callout)
                    .foregroundStyle(Theme.pixelInk)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Your salary is \(state.life.founderSalary.money) a week; the money card above the home sets it.")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(Theme.pixelInk.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func summary(_ state: GameState) -> String {
        guard state.life.homeDistrict != nil,
              let commute = state.homeCommute(balance: engine.balance)
        else {
            return "Your home has no district yet: the flat rate, and no commute. Pick one and the rent reads the district — cheap and far costs evenings, near and dear costs money."
        }
        return commute.isFar
            ? "The commute is far: \(commute.line)."
            : "The commute is near: every evening is yours."
    }

    // MARK: - A district

    private func row(_ quote: HomeMoveQuote) -> some View {
        let evenings = eveningsColumn(quote)
        return Button { move(quote.district) } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack {
                    Text(quote.district.displayName)
                        .font(.system(.headline, design: .rounded))
                    Spacer(minLength: Theme.Spacing.sm)
                    Text(quote.isCurrent ? "You live here" : quote.commute.isFar ? "Far" : "Near")
                        .font(.caption.weight(.semibold))
                }
                // The two prices, side by side (life.md §3's "how it fails":
                // if one column always wins, the other is wrong).
                HStack(alignment: .top, spacing: Theme.Spacing.md) {
                    column(
                        "Rent",
                        value: "\(quote.weeklyRent.money)/wk",
                        detail: quote.salaryPercent.map { "this costs \($0)% of your salary" }
                            ?? "no salary to measure it by"
                    )
                    column("Evenings", value: evenings.value, detail: evenings.detail)
                    // MARK: T6 (away) — J6: the third column, what is a walk from this home.
                    column("Nearby", value: nearby(quote).value, detail: nearby(quote).detail)
                    // MARK: end T6
                }
                Text(quote.blocker ?? "Move for \(quote.moveCost.money) and an evening")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(PixelButtonStyle(fill: quote.isCurrent ? Theme.pixelAccent : Theme.pixelPaper))
        .disabled(quote.blocker != nil)
        .opacity(quote.blocker == nil || quote.isCurrent ? 1 : 0.6)
        .accessibilityLabel(accessibilityLabel(quote, evenings: evenings))
    }

    private func column(_ title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .opacity(0.7)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
            Text(detail)
                .font(.caption2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The evenings column: every one of them when near, "−1 of 3" when
    /// the commute eats one.
    private func eveningsColumn(_ quote: HomeMoveQuote) -> (value: String, detail: String) {
        let commute = quote.commute
        guard let base = commute.eveningsBase else {
            return (commute.isFar ? "far" : "near", "no evening budget")
        }
        guard commute.isFar else { return ("all \(base)", "near: the office is close") }
        guard commute.eveningsLost > 0 else {
            return ("all \(base)", "far, but this week's schedule absorbs it")
        }
        return ("−\(commute.eveningsLost) evening of \(base)", "far: the commute eats it, every week")
    }

    // MARK: T6 (away)
    /// "the hacker house", and whatever else stands near that home.
    private func nearby(_ quote: HomeMoveQuote) -> (value: String, detail: String) {
        let parts = engine.state.homeNearby(quote.district, balance: engine.balance)
        guard let first = parts.first else { return ("—", "") }
        return (first, parts.dropFirst().joined(separator: " · "))
    }
    // MARK: end T6

    private func accessibilityLabel(
        _ quote: HomeMoveQuote, evenings: (value: String, detail: String)
    ) -> String {
        var parts = [quote.district.displayName, "\(quote.weeklyRent.money) a week"]
        if let pct = quote.salaryPercent { parts.append("\(pct)% of your salary") }
        parts.append("evenings: \(evenings.value)")
        parts.append(quote.blocker ?? "move for \(quote.moveCost.money) and an evening")
        return parts.joined(separator: ", ")
    }

    // MARK: - The move

    private func move(_ district: DistrictID) {
        engine.send(.moveHome(district: district))
        guard engine.state.life.homeDistrict == district else {
            Haptics.warning()
            shell.toasts.show(
                "The move fell through.",
                icon: "exclamationmark.triangle.fill",
                tint: Theme.warning,
                severity: .notable
            )
            return
        }
        Haptics.commit()
        let rent = engine.state.homeWeeklyRent(balance: engine.balance)
        let commute = engine.state.homeCommute(balance: engine.balance)?.line ?? "near"
        shell.toasts.show(
            "Moved to \(district.displayName): \(rent.money) a week, commute \(commute).",
            icon: "house.fill",
            tint: Theme.accent
        )
    }
}

// MARK: end K6
