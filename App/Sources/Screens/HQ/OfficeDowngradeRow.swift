import PixelKit
import SwiftUI
import TycoonEngine

// MARK: S2 (office downgrade)

/// Iteration 16 — S2. The move down, beside the move up on the office card:
/// one row that prints what it saves and what it costs (or why it is
/// refused), a sheet with the whole ledger and the button, and a line for
/// the amenities in storage since the last move down.
///
/// The engine owns every number (`GameState.officeDowngradeQuote`) and every
/// refusal; this prints them and sends `.downgradeOffice`.
struct OfficeDowngradeSection: View {
    let engine: GameEngine

    @State private var showingSheet = false
    /// `-autoRoute s2-storage`: the amenities sheet after the move, from here.
    @State private var showingStorage = false

    var body: some View {
        let state = engine.state
        let quote = state.officeDowngradeQuote(balance: engine.balance)
        let stored = state.officeStoredAmenities
        Group {
            if let quote {
                Divider()
                OfficeDowngradeRow(quote: quote) { showingSheet = true }
            }
            if !stored.isEmpty {
                Divider()
                OfficeStorageLine(stored: stored, balance: engine.balance)
            }
        }
        .sheet(isPresented: $showingSheet) {
            OfficeDowngradeSheet(engine: engine)
        }
        .sheet(isPresented: $showingStorage) {
            AmenitiesSheet(engine: engine)
        }
        .task {
            switch DebugLaunch.startOfficeDowngrade(engine: engine) {
            case .sheet: showingSheet = true
            case .storage: showingStorage = true
            case .none: break
            }
        }
    }
}

// MARK: - The row

/// "Move down: Loft", with the week's saving, the move's price, the drag and
/// the dent printed under it, or the first refusal in its place.
private struct OfficeDowngradeRow: View {
    let quote: OfficeDowngradeQuote
    let open: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Move down: \(quote.to.displayName)")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    Text(OfficeDowngradeCopy.savingLine(quote) + " · \(quote.moveCost.money) to move")
                        .font(Theme.Typography.number(.caption, weight: .regular))
                        .foregroundStyle(.secondary)
                    Text(OfficeDowngradeCopy.costLine(quote))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    if let sale = quote.salePrice {
                        Text("Sells the office for \(sale.money) and rents from then on")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: Theme.Spacing.sm)
                // Tappable when refused too: the sheet says what would
                // make it legal. Dimmed, like the rest of the refused rows.
                Button("Move down", action: open)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .buttonStyle(PixelButtonStyle(fill: Theme.pixelPaper))
                    .fixedSize()
                    .opacity(quote.refusal == nil ? 1 : 0.6)
            }
            if let refusal = quote.refusal {
                Text(refusal)
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(Theme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens what the move down saves and costs")
    }

    private var accessibilityLabel: String {
        var parts = [
            "Move down to the \(quote.to.displayName)",
            OfficeDowngradeCopy.savingLine(quote),
            "\(quote.moveCost.money) to move",
            OfficeDowngradeCopy.costLine(quote),
        ]
        if let sale = quote.salePrice { parts.append("sells the office for \(sale.money)") }
        if let refusal = quote.refusal { parts.append(refusal) }
        return parts.joined(separator: ", ")
    }
}

/// The amenities a move down put into storage, and what brings them back.
private struct OfficeStorageLine: View {
    let stored: [Amenity]
    let balance: BalanceConfig

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: "shippingbox.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("In storage: \(OfficeDowngradeCopy.list(stored.map(\.displayName)))")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Text(OfficeDowngradeCopy.storageLine(stored, balance: balance))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - The sheet

/// The whole ledger of the move down: what it saves, what it costs, what
/// changes and what refuses it, with the move priced on its own button.
struct OfficeDowngradeSheet: View {
    let engine: GameEngine

    @Environment(\.dismiss) private var dismiss
    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// See `GameShell.shared`: read optionally, because SwiftUI
    /// updates this property for presented content before the
    /// environment is installed and the non-optional form traps there.
    private var shell: GameShell { injectedShell ?? .shared }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let quote = engine.state.officeDowngradeQuote(balance: engine.balance) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        header(quote)
                        section("What it saves", lines: saves(quote))
                        section("What it costs", lines: costs(quote))
                        section("What changes", lines: changes(quote))
                        if !quote.refusals.isEmpty {
                            section("Not yet", lines: quote.refusals, tint: Theme.warning)
                        }
                        moveButton(quote)
                    }
                    .padding(Theme.Spacing.lg)
                } else {
                    Text("The garage is as small as it gets.")
                        .font(.callout)
                        .padding(Theme.Spacing.lg)
                }
            }
            .background(Theme.screenBackground)
            .navigationTitle("A smaller office")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Stay put") { dismiss() }
                }
            }
        }
    }

    // MARK: Header

    private func header(_ quote: OfficeDowngradeQuote) -> some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(alignment: .center, spacing: Theme.Spacing.md) {
                    PixelIconTile(systemImage: "shippingbox.fill", tint: Theme.accent, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        PixelText(
                            text: "\(quote.from.displayName) to \(quote.to.displayName)",
                            scale: 2,
                            color: Theme.pixelInk
                        )
                        Text(OfficeDowngradeCopy.savingLine(quote))
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(Theme.pixelInk.opacity(0.7))
                    }
                }
                Text("Less rent every week, for a company that looks smaller from the inside and the outside.")
                    .font(.callout)
                    .foregroundStyle(Theme.pixelInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Lines

    private func saves(_ quote: OfficeDowngradeQuote) -> [String] {
        var lines: [String] = []
        if let sale = quote.salePrice {
            lines.append("Sells the \(engine.state.city.district.displayName) office today for \(sale.money)")
            lines.append("Property tax \(quote.propertyTaxNow.money) a week → rent \(quote.rentAfter.money) a week")
        } else {
            lines.append("Rent \(quote.rentNow.money) → \(quote.rentAfter.money) a week")
        }
        if quote.upkeepStored > 0 {
            lines.append("\(quote.upkeepStored.money) a week of amenity upkeep stops")
        }
        lines.append(OfficeDowngradeCopy.savingLine(quote).prefix(1).uppercased()
            + OfficeDowngradeCopy.savingLine(quote).dropFirst() + ", every week")
        return lines
    }

    private func costs(_ quote: OfficeDowngradeQuote) -> [String] {
        let weeks = max(1, Int((Double(quote.moraleDragDays) / 7).rounded()))
        var lines = [
            "\(quote.moveCost.money) to move: the van, and \(OfficeDowngradeCopy.weeks(engine.balance.officeDowngrade.moveCostRentWeeks)) of the old rent",
            "Everyone's morale target −\(OfficeDowngradeCopy.points(quote.moraleDrag)) for \(weeks) weeks: people read a smaller office as a company shrinking",
            "Reputation −\(OfficeDowngradeCopy.points(quote.reputationCost)), on the day",
        ]
        if quote.officeMoraleNow != quote.officeMoraleAfter {
            lines.append(
                "The room itself: morale target +\(OfficeDowngradeCopy.points(quote.officeMoraleNow)) → +\(OfficeDowngradeCopy.points(quote.officeMoraleAfter)), for as long as you stay"
            )
        }
        if -quote.moraleTargetChange > quote.moraleDrag {
            lines.append(
                "All told, the morale target moves −\(OfficeDowngradeCopy.points(-quote.moraleTargetChange)) on the day; \(OfficeDowngradeCopy.points(quote.moraleDrag)) of it comes back after \(weeks) weeks"
            )
        }
        let back = engine.balance.office(quote.from).upgradeCost
        if back > 0 {
            lines.append("Moving back up costs the \(quote.from.displayName)'s \(back.money) again")
        }
        return lines
    }

    private func changes(_ quote: OfficeDowngradeQuote) -> [String] {
        var lines = [
            "\(quote.desksAfter) desks · \(quote.slotsAfter) build\(quote.slotsAfter == 1 ? "" : "s") at a time",
        ]
        if !quote.storedAmenities.isEmpty {
            lines.append(
                "\(OfficeDowngradeCopy.list(quote.storedAmenities.map(\.displayName))) into storage: no upkeep, and their morale target +\(OfficeDowngradeCopy.points(quote.storedMoraleBonus)) goes with them until you move back up"
            )
        }
        if quote.losesLaunchEvents {
            lines.append("No launch events below the \(engine.balance.launchEventMinTier.capitalized)")
        }
        lines.append("Every goal already reached stays reached")
        return lines
    }

    private func section(_ title: String, lines: [String], tint: Color = Theme.pixelInk) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .kerning(0.6)
                .foregroundStyle(.secondary)
            ForEach(lines, id: \.self) { line in
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                    Text("·")
                    Text(line)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(tint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: The move

    private func moveButton(_ quote: OfficeDowngradeQuote) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Button { move(quote) } label: {
                Text("Move down to the \(quote.to.displayName) for \(quote.moveCost.money)")
                    .font(.system(.headline, design: .rounded))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PixelButtonStyle(fill: quote.refusal == nil ? Theme.pixelAccent : Theme.pixelPaper))
            .disabled(quote.refusal != nil)
            .opacity(quote.refusal == nil ? 1 : 0.55)
            Text(quote.refusal ?? "Cash after the move: \(quote.cashAfter(from: engine.state.company.cash).money)")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(quote.refusal == nil ? Color.secondary : Theme.warning)
        }
    }

    private func move(_ quote: OfficeDowngradeQuote) {
        engine.send(.downgradeOffice)
        guard engine.state.company.officeTier == quote.to else {
            Haptics.warning()
            shell.toasts.show(
                engine.state.officeDowngradeBlocker(balance: engine.balance) ?? "The move fell through.",
                icon: "hand.raised.fill",
                tint: Theme.warning,
                severity: .notable
            )
            return
        }
        Haptics.commit()
        shell.toasts.show(
            "Moved down to the \(quote.to.displayName). \(OfficeDowngradeCopy.savingLine(quote).prefix(1).uppercased() + OfficeDowngradeCopy.savingLine(quote).dropFirst()).",
            icon: "shippingbox.fill",
            tint: Theme.accent
        )
        dismiss()
    }
}

// MARK: - Copy

enum OfficeDowngradeCopy {
    /// "saves $1,400 a week", or what it costs more when an owned office's
    /// tax was less than the new rent.
    static func savingLine(_ quote: OfficeDowngradeQuote) -> String {
        let saved = quote.weeklySaved
        if saved > 0 { return "saves \(saved.money) a week" }
        if saved == 0 { return "saves nothing a week" }
        return "costs \((-saved).money) more a week: rent again"
    }

    /// "Morale target −23 (5 of it for 13 weeks) · reputation −3"
    static func costLine(_ quote: OfficeDowngradeQuote) -> String {
        let weeks = max(1, Int((Double(quote.moraleDragDays) / 7).rounded()))
        let total = -quote.moraleTargetChange
        let morale = total > quote.moraleDrag
            ? "Morale target −\(points(total)) (\(points(quote.moraleDrag)) of it for \(weeks) weeks)"
            : "Morale target −\(points(total)) for \(weeks) weeks"
        return morale + " · reputation −\(points(quote.reputationCost))"
    }

    static func storageLine(_ stored: [Amenity], balance: BalanceConfig) -> String {
        let ladder = OfficeTier.allCases
        let smallest = stored.map { balance.company.amenity($0).minTier }
            .min { (ladder.firstIndex(of: $0) ?? 0) < (ladder.firstIndex(of: $1) ?? 0) }
        let tier = smallest.map { "the \($0.displayName)" } ?? "a bigger office"
        return "Kept, not sold: no upkeep and no effect until the office can hold \(stored.count == 1 ? "it" : "them"). Back out of the boxes at \(tier)."
    }

    static func weeks(_ count: Int) -> String {
        switch count {
        case 1: "a week"
        case 2: "two weeks"
        default: "\(count) weeks"
        }
    }

    static func points(_ value: Double) -> String {
        value == value.rounded() ? "\(Int(value))" : String(format: "%.1f", value)
    }

    static func list(_ names: [String]) -> String {
        switch names.count {
        case 0: ""
        case 1: names[0]
        case 2: "\(names[0]) and \(names[1])"
        default: names.dropLast().joined(separator: ", ") + " and " + names[names.count - 1]
        }
    }
}

// MARK: end S2
