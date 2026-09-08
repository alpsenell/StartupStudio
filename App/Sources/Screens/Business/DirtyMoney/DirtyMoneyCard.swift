import SwiftUI
import TycoonEngine

/// Iteration 11, wave two — W1. The card that sits under the bank loan on
/// the Business tab's finances, because that is where a founder is when
/// they decide this.
///
/// Four states, because the feature has four: nobody is offering anything
/// (no card at all — a card that said "no criminals have called" would be
/// an advert for the feature), an offer with a week on it, a backer with
/// strings and a thermometer, and an ending that the record keeps.
struct DirtyMoneyCard: View {
    let engine: GameEngine

    @State private var showingOffer = false
    @State private var showingDemand = false
    @State private var showingExits = false

    private var state: GameState { engine.state }
    private var money: DirtyMoneyState { engine.state.dirtyMoney }

    var body: some View {
        Group {
            if money.hasOffer(on: state.day), let backer = money.offeredKind {
                CardView("An approach", systemImage: backer.symbol) {
                    offer(backer)
                }
            } else if let backer = money.backerKind {
                CardView("The facility", systemImage: backer.symbol) {
                    backed(backer)
                }
            } else if let exit = money.exit {
                CardView("The facility", systemImage: "checkmark.seal.fill") {
                    ended(exit)
                }
            }
        }
        .sheet(isPresented: $showingOffer) {
            if let backer = money.offeredKind {
                DirtyMoneyOfferSheet(engine: engine, backer: backer)
            }
        }
        .sheet(isPresented: $showingDemand) {
            if let demand = money.openDemand, let backer = money.backerKind {
                DirtyMoneyDemandSheet(engine: engine, demand: demand, backer: backer)
            }
        }
        .sheet(isPresented: $showingExits) {
            if let backer = money.backerKind {
                DirtyMoneyExitSheet(engine: engine, backer: backer)
            }
        }
        .task {
            DirtyMoneyDebug.startIfAsked(engine: engine)
            await DirtyMoneyDebug.openWhenOffered(engine: engine) { showingOffer = true }
            await DirtyMoneyDebug.openWayOutWhenBacked(engine: engine) { showingExits = true }
        }
        // A string arriving while the player is on this screen opens
        // itself: it is the interruption, and there is nothing behind it.
        .onChange(of: money.openDemand?.id) { _, id in
            guard id != nil, !showingExits else { return }
            showingOffer = false
            showingDemand = true
        }
        // An offer that was taken, declined or left to expire takes its
        // own sheet with it rather than leaving an empty one up.
        .onChange(of: money.offeredBacker) { _, backer in
            if backer == nil { showingOffer = false }
        }
    }

    // MARK: - Somebody has called

    @ViewBuilder
    private func offer(_ backer: DirtyMoneyBacker) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(backer.displayName)
                    .font(.system(.headline, design: .rounded))
                Text(backer.blurb)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(alignment: .firstTextBaseline) {
                Text(money.offeredCheque.money)
                    .font(Theme.Typography.number(.title3))
                    .foregroundStyle(Theme.positiveCash)
                Spacer(minLength: Theme.Spacing.sm)
                if let by = money.offerRespondByDay {
                    Text(by - state.day <= 0
                        ? "Today"
                        : "\(by - state.day) day\(by - state.day == 1 ? "" : "s")")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.warning)
                }
            }
            Text(backer.stringsLine)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Hear them out", systemImage: "envelope.open.fill") {
                Haptics.tap()
                showingOffer = true
            }
            .buttonStyle(.pressable)
            .font(.footnote.weight(.semibold))
        }
    }

    // MARK: - Their money is in the account

    @ViewBuilder
    private func backed(_ backer: DirtyMoneyBacker) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(backer.displayName)
                    .font(.system(.headline, design: .rounded))
                Text(sinceLine)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            DirtyMoneyThermometer(heat: money.heat)

            if let demand = money.openDemand {
                DirtyMoneyDemandRow(demand: demand, day: state.day) {
                    Haptics.tap()
                    showingDemand = true
                }
            } else {
                Text(quietLine(backer))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            costs(backer)

            Button("The way out", systemImage: "door.left.hand.open") {
                Haptics.tap()
                showingExits = true
            }
            .buttonStyle(.pressable)
            .font(.footnote.weight(.semibold))
        }
    }

    private var sinceLine: String {
        guard let taken = money.takenDay else { return "" }
        let weeks = max(0, (state.day - taken) / GameState.daysPerWeek)
        return "\(money.cheque.money), banked \(weeks) week\(weeks == 1 ? "" : "s") ago"
    }

    private func quietLine(_ backer: DirtyMoneyBacker) -> String {
        switch backer {
        case .familyOffice: "Nothing this week. They send a note every Friday that says only 'noted'."
        case .theFront: "Nothing this week. The next invoice will arrive on a Tuesday, as they all do."
        case .theShark: "Nothing this week beyond the vig, which he does not consider a thing."
        }
    }

    /// What they cost, weekly, in the founder's own words and in figures.
    @ViewBuilder
    private func costs(_ backer: DirtyMoneyBacker) -> some View {
        let vig = state.dirtyMoneyWeeklyVig(balance: engine.balance)
        let passengers = money.passengerWeeklyCost
        if vig > 0 || passengers > 0 || money.laundered > 0 {
            VStack(alignment: .leading, spacing: 4) {
                if vig > 0 {
                    DirtyMoneyFigureRow(
                        label: "The vig, weekly", value: vig.money, tint: Theme.negativeCash
                    )
                }
                if passengers > 0 {
                    DirtyMoneyFigureRow(
                        label: money.passengers.map(\.name).formatted(.list(type: .and))
                            + ", weekly",
                        value: passengers.money,
                        tint: Theme.negativeCash
                    )
                }
                if money.laundered > 0 {
                    DirtyMoneyFigureRow(
                        label: "Through them, all in",
                        value: money.laundered.money,
                        tint: Theme.warning
                    )
                }
            }
        }
    }

    // MARK: - It is over

    @ViewBuilder
    private func ended(_ exit: DirtyMoneyExit) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(exit.displayName)
                .font(.system(.headline, design: .rounded))
            Text(endingLine(exit))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if money.laundered > 0 {
                Text("\(money.laundered.money) went through them. The record has all of it.")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if exit == .turnedWitness {
                DirtyMoneyThermometer(heat: money.heat)
            }
        }
    }

    private func endingLine(_ exit: DirtyMoneyExit) -> String {
        switch exit {
        case .paidOff:
            "You bought your way out. They were warm about it, which after everything is the part you remember."
        case .turnedWitness:
            "You gave a statement. It does not end when the case does."
        case .soldUp:
            "They own it now."
        }
    }
}

// MARK: - The thermometer

/// Heat as a thermometer rather than a bar: it is a temperature somebody
/// else takes of you, and it goes down on its own if you leave it alone.
struct DirtyMoneyThermometer: View {
    let heat: Double

    private var tint: Color {
        switch heat {
        case ..<20: Theme.positiveCash
        case ..<45: Theme.warning
        default: Theme.negativeCash
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("HEAT")
                    .font(.caption2.weight(.bold))
                    .kerning(0.8)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text("\(Int(heat.rounded()))")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.chipBackground)
                    Capsule()
                        .fill(tint)
                        .frame(width: max(2, geometry.size.width * heat / 100))
                }
            }
            .frame(height: 8)
            .animation(Theme.Motion.valueChange, value: heat)
            Text(DirtyMoney.heatLabel(heat))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Heat \(Int(heat.rounded())) of 100. \(DirtyMoney.heatLabel(heat)).")
    }
}

// MARK: - Small rows

/// The string they are pulling, with its clock.
struct DirtyMoneyDemandRow: View {
    let demand: DirtyMoneyDemand
    let day: Int
    let tap: () -> Void

    var body: some View {
        Button(action: tap) {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                Image(systemName: demand.kind.symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.negativeCash)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(demand.kind.title)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    Text(clock)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(Theme.warning)
                }
                Spacer(minLength: Theme.Spacing.sm)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressableRow)
        .accessibilityLabel("\(demand.kind.title). \(clock)")
    }

    private var clock: String {
        let left = demand.daysLeft(from: day)
        let amount = demand.amount > 0 ? "\(demand.amount.money) · " : ""
        return left == 0
            ? "\(amount)they want an answer today"
            : "\(amount)\(left) day\(left == 1 ? "" : "s") to answer"
    }
}

/// A label and a figure on one line, the way the loan card reads.
struct DirtyMoneyFigureRow: View {
    let label: String
    let value: String
    var tint: Color = .primary

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: Theme.Spacing.sm)
            Text(value)
                .font(Theme.Typography.number(.caption))
                .foregroundStyle(tint)
        }
        .accessibilityElement(children: .combine)
    }
}
