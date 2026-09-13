import SwiftUI
import TycoonContent
import TycoonEngine

// MARK: T5 (expo and pre-orders)

/// Iteration 17 — T5 (G2). The expo on the Now card: from four weeks out,
/// *Expo in N days*, what is booked, and the button that opens the sheet.
/// Renders nothing outside the notice window, once the year is done, and
/// with nothing in development. The rail's queued entry (`Route.expo`)
/// lands here too.
struct ExpoNowRow: View {
    let engine: GameEngine

    /// Optional for the reason `LaunchDaySheet` gives: a card can be
    /// redrawn while its host is being torn down.
    @Environment(AppRouter.self) private var router: AppRouter?
    @State private var showingSheet = false

    var body: some View {
        let state = engine.state
        if let left = state.expoDaysLeft(balance: engine.balance), !state.productsInDevelopment.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack(alignment: .firstTextBaseline) {
                    Label(
                        left == 0 ? "The expo is today" : "Expo in \(left) day\(left == 1 ? "" : "s")",
                        systemImage: "person.3.sequence.fill"
                    )
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    Spacer(minLength: Theme.Spacing.sm)
                    Text(AnnounceEventPresenter.dateLabel(state.expoDay(balance: engine.balance), today: state.day))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(ExpoCopy.nowLine(state: state, balance: engine.balance))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    Haptics.tap()
                    showingSheet = true
                } label: {
                    Label(state.expoBooking == nil ? "Plan the expo" : "Change the demo", systemImage: "megaphone.fill")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.xs)
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
                .accessibilityHint("Opens the expo: which build, who goes, and what it costs")
            }
            .accessibilityElement(children: .contain)
            .sheet(isPresented: $showingSheet) {
                ExpoSheet(engine: engine)
            }
            .onChange(of: router?.pendingPush, initial: true) { _, _ in
                if router?.take(.expo) == true { showingSheet = true }
            }
        }
    }
}

/// The words the expo says on the card, the sheet and in the journal.
enum ExpoCopy {
    /// The show's name.
    static let showName = "DevWorld"

    /// "30", "0.7": a balance number without trailing zeros.
    static func number(_ value: Double) -> String {
        value == value.rounded() ? "\(Int(value))" : String(format: "%g", value)
    }

    /// "$4.99", "$12": a unit price.
    static func price(_ value: Double) -> String {
        value == value.rounded() ? "$\(Int(value))" : String(format: "$%.2f", value)
    }

    /// The Now card's second line.
    static func nowLine(state: GameState, balance: BalanceConfig) -> String {
        let config = balance.expo
        if let booking = state.expoBooking, let product = state.product(id: booking.productID) {
            let stand = booking.booth == .booth ? "a booth" : "the hallway"
            let who = booking.attendee == .founder ? "you at it" : "a marketer at it"
            var line = "\(product.name) at \(stand), \(who)."
            if case .development(let dev) = product.stage, dev.openBugs > config.crashBugs {
                line += " \(dev.openBugs) open bugs: over \(config.crashBugs) the demo crashes."
            }
            return line
        }
        let hallway = config.hallway.money
        let booth = state.expoPrice(.booth, balance: balance).map { "a booth for \($0.money) or the hallway for \(hallway)" }
            ?? "the hallway for \(hallway) (a booth needs an office)"
        return "One build, \(booth). Over \(config.crashBugs) open bugs the demo crashes."
    }
}

/// What the expo and pre-order events say in the journal, the toast layer
/// and the newspaper (whose lead is `EventCopy`'s line, compressed).
/// `EventCopy`'s switch calls into this from its T5 region.
enum ExpoEventPresenter {
    /// Icon, line, day and tint, in `EventCopy`'s shape.
    static func entry(for event: GameEvent, state: GameState) -> (String, String, Int, Color)? {
        switch event {
        case let .expoBooked(productID, booth, attendee, price, day):
            let name = name(of: productID, in: state)
            if price == 0 {
                return ("megaphone.fill", "The expo stand will show \(name) now", day, Theme.accent)
            }
            let stand = booth == .booth ? "a booth" : "a hallway pass"
            let who = attendee == .founder ? "You will be there" : "A marketer will be there"
            return ("megaphone.fill", "Booked \(stand) at \(ExpoCopy.showName) for \(name), \(price.money). \(who)", day, Theme.accent)
        case let .expoShown(productID, _, _, hype, reputation, crashed, staffed, day):
            let name = name(of: productID, in: state)
            let hypeText = "+\(Int(hype.rounded())) hype"
            if crashed {
                return (
                    "exclamationmark.triangle.fill",
                    "\(name)'s demo crashed on the \(ExpoCopy.showName) floor. \(hypeText) anyway, and the paper was there",
                    day, Theme.negativeCash
                )
            }
            let crowd = staffed ? "" : " Nobody from the company was at the stand."
            let verdict = reputation > 0 ? "and the press liked what it saw" : "and the rivals took notes"
            return ("person.3.sequence.fill", "\(name) at \(ExpoCopy.showName): \(hypeText), \(verdict).\(crowd)", day, Theme.positiveCash)
        case let .expoEmptyBooth(productID, day):
            return (
                "person.fill.questionmark",
                "The expo stand stood empty: \(name(of: productID, in: state)) was no longer a demo",
                day, Theme.warning
            )
        case let .expoSkipped(day):
            return ("moon.zzz.fill", "You let \(ExpoCopy.showName) go this year. The board stays dark", day, Theme.accent)
        case let .preordersOpened(productID, units, cash, day):
            return (
                "cart.fill",
                "\(name(of: productID, in: state)) opened pre-orders: \(units) sold, \(cash.money) in",
                day, Theme.positiveCash
            )
        case let .preordersRefunded(productID, units, cash, voided, day):
            let name = name(of: productID, in: state)
            return voided
                ? ("cart.badge.minus", "\(name)'s pre-orders refunded in full: \(cash.money) back out, and a forum thread about it", day, Theme.negativeCash)
                : ("cart.badge.minus", "\(name) slipped: \(units) pre-orders refunded, \(cash.money)", day, Theme.warning)
        case let .preordersDelivered(productID, units, day):
            return (
                "shippingbox.fill",
                "\(name(of: productID, in: state)) delivered \(units) pre-orders in its launch week, paid for months ago",
                day, Theme.accent
            )
        default:
            return nil
        }
    }

    private static func name(of productID: UUID, in state: GameState) -> String {
        state.product(id: productID)?.name ?? "The build"
    }
}

/// `-autoExpo <steps>`: sends the engine's debug seed once, on launch.
@MainActor
enum ExpoDebug {
    private static var started = false

    static func start(engine: GameEngine) {
        #if DEBUG
        guard !started, let scenario = DebugLaunch.autoExpoScenario else { return }
        started = true
        _ = engine.send(.expoDebugSeed(scenario: scenario))
        #endif
    }
}

// MARK: end T5
