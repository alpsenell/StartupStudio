import PixelKit
import SwiftUI
import TycoonContent
import TycoonEngine

// MARK: J5 (announce)

/// Iteration 12 — J5. The ship date on a build's page: the button that
/// opens the sheet, or the date that stands and whether today's ETA makes
/// it. Rule 7: when a date cannot be given, the card says why.
struct AnnounceCard: View {
    let engine: GameEngine
    let product: Product

    @State private var showingSheet = false

    private var state: GameState { engine.state }

    var body: some View {
        CardView("Ship date", systemImage: "megaphone.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                content
                // MARK: T4 (publisher) — the Financing row beside the date:
                // shop the build to a publisher, or the deal that stands.
                PublisherRow(engine: engine, product: product)
                // MARK: end T4
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $showingSheet) {
            AnnounceSheet(engine: engine, productID: product.id)
        }
        .onAppear {
            if AnnounceRoute.takeSheetRequest(for: product.id) { showingSheet = true }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let date = product.announcedDay {
            announced(date)
        } else if product.announceIsVoid {
            Text("Two dates missed. The press stopped printing them for this one.")
                .font(.footnote)
                .foregroundStyle(Theme.negativeCash)
        } else if let refusal = blocking {
            Text(refusal.sentence)
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if let proposal = state.announceProposal(
            productID: product.id, slackDays: AnnounceSheet.defaultSlack,
            balance: engine.balance, content: engine.content
        ) {
            let cost = Announce.slipCost(slipNumber: 1, balance: engine.balance)
            Button {
                showingSheet = true
            } label: {
                Label("Announce for \(label(proposal))", systemImage: "megaphone.fill")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.xs)
            }
            .buttonStyle(.bordered)
            .tint(Theme.accent)
            .accessibilityHint("Opens the announcement, with every date and what it costs")
            Text("Hype holds and campaigns land ×\(format(engine.balance.announce.campaignFactor)) · miss it: reputation −\(Int(cost.reputation)), hype ×\(format(cost.hypeFactor))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The reason no date can be given today, other than the date itself.
    private var blocking: AnnounceRefusal? {
        let refusal = state.announceRefusal(
            productID: product.id, day: state.announceEarliestDay(balance: engine.balance),
            balance: engine.balance, content: engine.content
        )
        return refusal == .tooSoon || refusal == .tooFar ? nil : refusal
    }

    @ViewBuilder
    private func announced(_ date: Int) -> some View {
        let left = date - state.day
        HStack(alignment: .firstTextBaseline) {
            Text("Announced for \(label(date))")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
            Spacer(minLength: Theme.Spacing.sm)
            Text(left <= 0 ? "Due today" : "\(left) day\(left == 1 ? "" : "s")")
                .font(Theme.Typography.number(.subheadline, weight: .semibold))
                .foregroundStyle(Theme.accent)
        }
        if state.announceIsBehind(product, balance: engine.balance, content: engine.content),
           let eta = state.shipETA(for: product, balance: engine.balance, content: engine.content) {
            let cost = Announce.slipCost(slipNumber: product.slips + 1, balance: engine.balance)
            Text("Today's ETA is \(label(eta.day)), \(eta.day - date) day\(eta.day - date == 1 ? "" : "s") past it. Crunch, or it slips: reputation −\(Int(cost.reputation)), hype ×\(format(cost.hypeFactor)).")
                .font(.footnote)
                .foregroundStyle(Theme.warning)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text("On track at today's pace. Hype fades \(Int((engine.balance.announce.hypeDecayRate * 100).rounded()))% a day and campaigns land ×\(format(engine.balance.announce.campaignFactor)).")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        if product.slips > 0 {
            Text("Slipped once already. The next miss voids it.")
                .font(.caption)
                .foregroundStyle(Theme.warning)
        }
        // MARK: T5 (expo and pre-orders) — the row under the date.
        PreorderRow(engine: engine, product: product)
        // MARK: end T5
    }

    private func label(_ day: Int) -> String {
        AnnounceEventPresenter.dateLabel(day, today: state.day)
    }

    private func format(_ value: Double) -> String {
        value == value.rounded() ? "\(Int(value))" : String(format: "%g", value)
    }
}

/// Iteration 12 — J5. The war room's second countdown: to the day the
/// press was told, under the one to the ETA. Renders nothing for a build
/// nobody announced.
struct AnnounceCountdownLine: View {
    let engine: GameEngine
    let product: Product

    var body: some View {
        if let date = product.announcedDay {
            let left = date - engine.state.day
            let behind = engine.state.announceIsBehind(product, balance: engine.balance, content: engine.content)
            VStack(spacing: 4) {
                PixelText(
                    text: left <= 0 ? "Promised today" : "Promised in \(left) day\(left == 1 ? "" : "s")",
                    scale: 2,
                    color: behind ? Theme.warning : Theme.pixelAccent
                )
                Text(caption(date: date, behind: behind))
                    .font(.caption)
                    .foregroundStyle(behind ? Theme.warning : Theme.pixelInk.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else if product.announceIsVoid {
            PixelText(
                text: String(localized: "Date void", comment: "War room: the announced ship date was missed twice and no longer stands. Pixel face, A-Z only"),
                scale: 2,
                color: Theme.negativeCash
            )
        }
    }

    private func caption(date: Int, behind: Bool) -> String {
        let label = AnnounceEventPresenter.dateLabel(date, today: engine.state.day)
        guard behind,
              let eta = engine.state.shipETA(for: product, balance: engine.balance, content: engine.content)
        else {
            // The date is kept at the ship gate. Say so when the finished
            // build lands after it: hitting it means shipping it rough.
            let done = engine.state.buildETA(
                productID: product.id, balance: engine.balance, content: engine.content
            )?.completionDay(from: engine.state.day)
            if let done, done > date {
                return "Announced for \(label) · the ship gate makes it; the finished build does not"
            }
            return "Announced for \(label) · on track"
        }
        let late = eta.day - date
        return "Announced for \(label) · the ETA is \(late) day\(late == 1 ? "" : "s") past it"
    }

    /// The same, as one sentence for the countdown panel's label.
    static func accessibilityText(for product: Product, engine: GameEngine) -> String? {
        if let date = product.announcedDay {
            let left = date - engine.state.day
            let behind = engine.state.announceIsBehind(product, balance: engine.balance, content: engine.content)
            return "Announced for \(AnnounceEventPresenter.dateLabel(date, today: engine.state.day)), "
                + (left <= 0 ? "due today" : "\(left) day\(left == 1 ? "" : "s") away")
                + (behind ? ", and the ETA is past it" : ", on track")
        }
        return product.announceIsVoid ? "The announced date is void" : nil
    }
}

/// Iteration 12 — J5. Where `Route.announce` lands: the build that most
/// wants a date — the soonest ETA that can still be announced — with its
/// sheet open. Also the target of `-autoPremium` in debug builds.
@MainActor
enum AnnounceRoute {
    /// A sheet the next `AnnounceCard` for this product should open.
    private static var sheetRequest: UUID?

    /// The product the route pushes, and a request for its sheet.
    static func target(in engine: GameEngine) -> UUID? {
        #if DEBUG
        if AnnounceDebug.wantsPremium, let id = AnnounceDebug.premiumCandidate(in: engine)?.id {
            return id
        }
        // MARK: T5 (expo and pre-orders) — `-autoRoute t5-preorders`: the
        // announced build (or the one about to be), its pre-order sheet open.
        if DebugLaunch.autoRouteName == "t5-preorders",
           let id = engine.state.announcedBuilds.first?.id ?? candidate(in: engine)?.id {
            PreorderRoute.sheetRequest = id
            return id
        }
        // MARK: end T5
        #endif
        guard let id = candidate(in: engine)?.id else { return nil }
        sheetRequest = id
        return id
    }

    /// The soonest-ETA build a date can still be given for.
    static func candidate(in engine: GameEngine) -> Product? {
        let state = engine.state
        return state.shipETAs(balance: engine.balance, content: engine.content)
            .compactMap { state.product(id: $0.productID) }
            .first { product in
                guard let day = state.announceProposal(
                    productID: product.id, slackDays: AnnounceSheet.defaultSlack,
                    balance: engine.balance, content: engine.content
                ) else { return false }
                return state.announceRefusal(
                    productID: product.id, day: day, balance: engine.balance, content: engine.content
                ) == nil
            }
    }

    /// `-autoRoute announce` (or `premium`) with `-autoTab products`: the
    /// tab root reads the launch route itself, once, the way the Business
    /// and Life roots read theirs.
    private static var tookLaunchRoute = false

    static func takeLaunchRoute() -> Bool {
        #if DEBUG
        guard !tookLaunchRoute, Route.launchRoute == .announce else { return false }
        tookLaunchRoute = true
        return true
        #else
        return false
        #endif
    }

    #if DEBUG
    private static var tookRoom = false

    /// `-autoRoute announceroom`: the war room on its own fixture engine
    /// (the way `-autoRoute warRoom` opens it), with the build far enough
    /// out to take a date, announced at the usual slack — and missed once
    /// with `-autoAnnounce slip`. A headless pass cannot reach a build that
    /// early in a live game without a play-through.
    static func debugRoom() -> WarRoomRequest? {
        guard !tookRoom, DebugLaunch.launchRoute == "announceroom" else { return nil }
        tookRoom = true
        // Early enough that the ship gate is still weeks off: the date has
        // to be given early (`announce.earlyLeadDays`).
        let engine = WarRoomFixture.engine(.countdown(daysOut: 85))
        guard let product = engine.state.productInDevelopment,
              let day = engine.state.announceProposal(
                  productID: product.id, slackDays: AnnounceSheet.defaultSlack,
                  balance: engine.balance, content: engine.content
              )
        else { return nil }
        _ = engine.send(.announceShipDate(productID: product.id, day: day))
        if DebugLaunch.autoAnnounceMode == .slip {
            _ = engine.send(.announceForceSlip(productID: product.id))
        }
        return WarRoomRequest(engine: engine, productID: product.id)
    }
    #endif

    /// Consumes the request if it is for `productID`.
    static func takeSheetRequest(for productID: UUID) -> Bool {
        guard sheetRequest == productID else { return false }
        sheetRequest = nil
        return true
    }
}

// MARK: end J5
