import Foundation
import SwiftUI
import TycoonEngine

/// What went wrong, in three lines at most, each with its number. Built
/// from state and the ledger for a failed ending; facts, never a scold.
enum PostMortem {
    struct Line: Equatable, Identifiable {
        let id: String
        let systemImage: String
        let text: String
    }

    // l10n: NOT LOCALIZED, deliberately (R9, iteration 7). Each line pairs a
    // fact with its number and pluralises with a trailing s. The conversion is
    // one keyed format per `Line.id` plus a plural variant per count -
    //   "postmortem.never-shipped" = "Nothing was ever started. %lld weeks of
    //                                 payroll and rent with no product to sell."
    //   "postmortem.burn"          = "%1$@ out against %2$@ in over the last quarter."
    // - because the ids are already stable and test-pinned. Wave 2.
    static func lines(for state: GameState, balance: BalanceConfig, weeklyBurn: Int) -> [Line] {
        var lines: [Line] = []
        let entries = state.ledger.entries
        let day = state.day

        // 1. Never shipped anything.
        let shipped = state.products.filter { if case .released = $0.stage { true } else { false } }
        if shipped.isEmpty {
            let weeks = max(1, day / 7)
            lines.append(Line(
                id: "never-shipped",
                systemImage: "shippingbox",
                text: state.products.isEmpty
                    ? "Nothing was ever started. \(weeks) week\(weeks == 1 ? "" : "s") of payroll and rent with no product to sell."
                    : "Nothing ever shipped. \(state.products.count) build\(state.products.count == 1 ? "" : "s") started, none reached the market in \(weeks) weeks."
            ))
        }

        // 2. Burn against income over the last quarter.
        let since = max(0, day - 91)
        let recent = entries.filter { $0.day >= since }
        let income = recent.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
        let spend = recent.filter { $0.amount < 0 }.reduce(0) { $0 - $1.amount }
        if spend > 0, income < spend / 2, day >= 28 {
            let weeks = max(1, (day - since) / 7)
            lines.append(Line(
                id: "burn",
                systemImage: "flame.fill",
                text: "Over the last \(weeks) weeks the company spent \(spend.money) and took in \(income.money) — about \(weeklyBurn.money) a week going out against \((income / weeks).money) coming in."
            ))
        }

        // 3. Hired before the first sale.
        let firstSale = entries.first { $0.category == .sales && $0.amount > 0 }?.day
        let hires = state.employees.filter { !$0.isFounder }
        let earlyHires = hires.filter { hire in firstSale.map { hire.hiredDay < $0 } ?? true }
        if !earlyHires.isEmpty, hires.count >= 2 {
            let payroll = hires.reduce(0) { $0 + $1.weeklySalary }
            lines.append(Line(
                id: "hired-early",
                systemImage: "person.2.fill",
                text: firstSale == nil
                    ? "\(hires.count) people on \(payroll.money)/wk of payroll before the first dollar of sales."
                    : "\(earlyHires.count) of \(hires.count) hires were on payroll before the first sale, at \(payroll.money)/wk."
            ))
        }

        // 4. Paying yourself above the room.
        if let founder = state.employees.first(where: \.isFounder), hires.count >= 2 {
            let median = hires.map(\.weeklySalary).sorted()[hires.count / 2]
            if Double(state.life.founderSalary) > Double(median) * 1.5, median > 0 {
                lines.append(Line(
                    id: "salary",
                    systemImage: "banknote.fill",
                    text: "\(founder.name) drew \(state.life.founderSalary.money)/wk against a team median of \(median.money)/wk — the room could see it."
                ))
            }
        }

        // 5. Rent for a bigger office than the cash carried.
        let rent = balance.office(state.company.officeTier).weeklyRent
        if rent > 0, weeklyBurn > 0, Double(rent) / Double(weeklyBurn) > 0.35 {
            lines.append(Line(
                id: "rent",
                systemImage: "building.2.fill",
                text: "The \(state.company.officeTier.displayName.lowercased()) cost \(rent.money)/wk in rent — \(Int((Double(rent) / Double(weeklyBurn) * 100).rounded()))% of the burn."
            ))
        }

        // MARK: K4 (deals and exits)
        // How the grace period ended: a sell-up leads with its day; the
        // receiver follows the first finding with what it cost the people.
        if let line = DealPostMortem.line(for: state, balance: balance) {
            lines.insert(line, at: state.gameOver?.kind == .soldUp ? 0 : min(1, lines.count))
        }
        // MARK: end K4

        return Array(lines.prefix(3))
    }
}

/// The post-mortem as a card: one line per finding, each with its number.
struct PostMortemCard: View {
    let lines: [PostMortem.Line]

    var body: some View {
        CardView("What went wrong", systemImage: "magnifyingglass") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                ForEach(lines) { line in
                    HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                        Image(systemName: line.systemImage)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.warning)
                            .frame(width: 20)
                        Text(line.text)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}
