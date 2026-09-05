import PixelKit
import SwiftUI
import TycoonContent
import TycoonEngine

/// The launch week war room: a full-screen mode for the last days before a
/// build ships, and for launch day.
///
/// The office with the crew at their desks and the pressure the build is
/// under; the countdown in the game's numeric face; the whiteboard with the
/// phase progress; the hype meter and what is feeding it; the forecast the
/// ship sheet computes, live; the press rolling in; and the clock, so the
/// week can be watched from here rather than from five cards on three tabs.
/// When the build ships from the room, the review reveal plays inside it —
/// the outlets one at a time, the cheer in the office — and the room ends
/// on the first week's numbers and a way back to the office.
///
/// Presented from the Products tab (the `.warRoom` route and the build
/// card) as a cover. Dismissable at any time; offered, never forced.
struct WarRoomScreen: View {
    let engine: GameEngine
    let productID: UUID

    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router
    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// See `GameShell.shared`: read optionally, because SwiftUI updates
    /// this property for presented content before the environment is
    /// installed and the non-optional form traps there.
    private var shell: GameShell { injectedShell ?? .shared }

    /// How many outlets the reveal has shown.
    @State private var revealed = 0
    /// The token the office cheers on; changes once per reveal.
    @State private var celebrationToken: Int?
    /// Whether the reveal has been started (or skipped) for this product.
    @State private var revealStarted = false
    @State private var confirmingShip = false

    private var product: Product? { engine.state.product(id: productID) }

    private var isReleased: Bool {
        if case .released = product?.stage { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                if let product {
                    WarRoomContent(
                        engine: engine,
                        product: product,
                        revealed: revealed,
                        celebrationToken: celebrationToken,
                        onShip: { confirmingShip = true },
                        onBack: { dismiss() },
                        onRoute: { route in
                            dismiss()
                            router.go(route)
                        }
                    )
                    .padding(Theme.Spacing.lg)
                } else {
                    ContentUnavailableView(
                        "Nothing to watch",
                        systemImage: "flag.checkered",
                        description: Text("This build is no longer in the save.")
                    )
                    .padding(.top, Theme.Spacing.xl)
                }
            }
        }
        // R8: a cover is presented at window level, so the game's column
        // does not reach it — on an iPad the room was 1,024 points of
        // stretched whiteboard. The room is still full screen; its
        // contents are a column, like everywhere else.
        .gameColumn()
        .onAppear {
            claimLaunchDay()
            startRevealIfNeeded()
            #if DEBUG
            // `-autoRoute shipInRoom`: the headless pass ships from here,
            // through the same call the button makes.
            if DebugLaunch.launchRoute == "shipinroom", !isReleased {
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    ship()
                }
            }
            #endif
        }
        .onChange(of: isReleased) { _, _ in startRevealIfNeeded() }
        // The shell opens the launch-day sheet for every ship; while the
        // room is up the moment is played here instead, so the request
        // is taken back before the root can present on top of the room.
        .onChange(of: engine.state.eventLog.count) { _, _ in claimLaunchDay() }
        .onChange(of: shell.launchDayProductID) { _, _ in claimLaunchDay() }
        .confirmationDialog(
            "Ship \(product?.name ?? "it")?",
            isPresented: $confirmingShip,
            titleVisibility: .visible
        ) {
            Button("Ship it") { ship() }
            Button("Keep working", role: .cancel) {}
        } message: {
            Text("Development stops for good and the press reviews whatever is finished.")
        }
    }

    // MARK: - Chrome

    /// Back, the room's name and today's date, and the clock. The room
    /// has no HUD: the one control the week needs is the speed.
    private var topBar: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.sm) {
            Button {
                Haptics.tap()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Back to the office")

            VStack(spacing: 3) {
                PixelText(text: "War room", scale: 2, color: Theme.pixelAccent, shadow: true)
                PixelText(text: engine.state.calendar.hudLabel, scale: 1, color: .secondary)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("War room, \(engine.state.calendar.longLabel)")

            SpeedControl(engine: engine, attention: !engine.lastPauseEvents.isEmpty)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
        .animation(Theme.Motion.entrance, value: engine.state.speed)
    }

    // MARK: - Shipping

    private func ship() {
        shell.toasts.send(
            .ship(productID: productID),
            to: engine,
            rejected: "It is not ready to ship yet."
        )
        // Synchronously, before any view updates: the reveal is ours.
        claimLaunchDay()
    }

    private func claimLaunchDay() {
        if shell.launchDayProductID == productID {
            shell.launchDayProductID = nil
        }
    }

    // MARK: - The reveal

    /// Plays launch day once: the fanfare, the cheer in the office, then
    /// the outlets one at a time on the same beat as `LaunchDaySheet`. A
    /// product launched on an earlier day has nothing to reveal — its
    /// reviews are simply shown.
    private func startRevealIfNeeded() {
        guard !revealStarted, let product, case .released(let info) = product.stage else { return }
        revealStarted = true
        guard info.launchDay == engine.state.day, !info.reviews.isEmpty else {
            revealed = info.reviews.count
            return
        }
        Sounds.play(.ship)
        Haptics.commit()
        Task {
            // A beat before the token moves, so a room opened on launch
            // day sees the celebration *change* rather than start set.
            try? await Task.sleep(for: .milliseconds(80))
            celebrationToken = engine.state.day * 100 + info.reviews.count
            for index in info.reviews.indices {
                try? await Task.sleep(for: .milliseconds(ReviewReveal.delay(forOutlet: index)))
                withAnimation(Theme.Motion.emphatic) { revealed = index + 1 }
                Sounds.play(.tap)
                Haptics.tap()
            }
        }
    }
}

// MARK: - Content

/// Everything in the room below the top bar. Takes the reveal's state
/// rather than owning it, so the launch-day frame can be rendered mid
/// reveal by the snapshot tests.
struct WarRoomContent: View {
    let engine: GameEngine
    let product: Product
    /// How many outlets have been revealed.
    var revealed: Int = 0
    /// The office's celebration token, once the reveal has started.
    var celebrationToken: Int?
    /// Whether the outlets' blurbs type themselves out. Off for a static
    /// frame (the snapshot tests render the reveal mid-way).
    var revealTypes = true
    var onShip: () -> Void = {}
    var onBack: () -> Void = {}
    var onRoute: (Route) -> Void = { _ in }

    private var type: ProductTypeDef? { engine.content.productType(product.typeID) }
    private var topic: TopicDef? { engine.content.topic(product.topicID) }

    private var eta: BuildETA? {
        engine.state.buildETA(productID: product.id, balance: engine.balance, content: engine.content)
    }

    private var forecast: ShipForecast? {
        engine.state.shipForecast(productID: product.id, balance: engine.balance, content: engine.content)
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            header
            CountdownPanel(product: product, eta: eta, forecast: forecast, engine: engine)
            scene
            switch product.stage {
            case .development(let progress):
                WhiteboardPanel(
                    product: product, progress: progress, type: type, eta: eta,
                    canShip: forecast?.canShip ?? false, engine: engine, onShip: onShip
                )
                HypePanel(product: product, hype: progress.hype, engine: engine, onRoute: onRoute)
                if let forecast {
                    ForecastBand(forecast: forecast)
                }
            case .released(let info):
                LaunchDayPanel(
                    product: product, release: info, revealed: revealed, typesOut: revealTypes,
                    engine: engine, onBack: onBack, onRoute: onRoute
                )
            }
            PressStripView(
                lines: PressStrip.lines(
                    for: product, state: engine.state, balance: engine.balance, content: engine.content
                )
            )
        }
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.md) {
            ProductBoxArtView(typeID: product.typeID, topicID: product.topicID, seed: product.boxArtSeed, size: 56)
                .shadow(color: Theme.pixelShadow, radius: 0, x: 2, y: 2)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                PixelText(text: product.name, scale: 3, color: Theme.pixelInk, shadow: true)
                Text("\(type?.name ?? product.typeID.capitalized) · \(topic?.name ?? product.topicID.capitalized)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(product.name), a \(type?.name ?? "product") about \(topic?.name ?? product.topicID)"
        )
    }

    /// The office, with the room's own reading of the crew and pressure.
    private var scene: some View {
        PixelPanel(contentPadding: Theme.Spacing.xs) {
            EquatableView(
                content: WarRoomScenePanel(
                    input: WarRoomScene.input(for: product, engine: engine, celebrationToken: celebrationToken),
                    label: sceneLabel
                )
            )
        }
        .frame(maxWidth: .infinity)
    }

    private var sceneLabel: String {
        let crew = WarRoomScene.crew(of: product, state: engine.state).count
        let tier = engine.state.company.officeTier.displayName
        return crew == 1
            ? "\(tier) office, one person on \(product.name)"
            : "\(tier) office, \(crew) people on \(product.name)"
    }
}

/// The scene inside an `EquatableView`, so the room's ticking state only
/// recomposes it when the office itself changes.
private struct WarRoomScenePanel: View, Equatable {
    let input: OfficeSceneInput
    let label: String

    var body: some View {
        OfficeSceneView(input: input)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(label)
    }
}

// MARK: - Countdown

/// The number the room is for, in the bitmap face: days to the ETA while
/// the build is in development, the day itself once it has shipped.
private struct CountdownPanel: View {
    let product: Product
    let eta: BuildETA?
    let forecast: ShipForecast?
    let engine: GameEngine

    private var day: Int { engine.state.day }

    var body: some View {
        PixelPanel {
            VStack(spacing: Theme.Spacing.sm) {
                switch product.stage {
                case .development:
                    development
                case .released(let info):
                    released(info)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var development: some View {
        if let days = eta?.daysToComplete {
            if days == 0 {
                PixelText(text: "Done", scale: 6, color: Theme.positiveCash)
                PixelText(text: "Every pool is full", scale: 2, color: .secondary)
            } else {
                PixelText(text: "T-minus", scale: 2, color: .secondary)
                HStack(alignment: .lastTextBaseline, spacing: Theme.Spacing.sm) {
                    PixelText(text: "\(days)", scale: 7, color: Theme.pixelAccent)
                    PixelText(text: days == 1 ? "day" : "days", scale: 3, color: Theme.pixelInk)
                }
                Text("ETA \(GameCalendar(day: day + days).longLabel)")
                    .font(Theme.Typography.number(.caption, weight: .regular))
                    .foregroundStyle(Theme.pixelInk.opacity(0.7))
            }
            if forecast?.canShip == true, days > 0 {
                Text("Past the ship gate — it could go out today.")
                    .font(.caption)
                    .foregroundStyle(Theme.positiveCash)
            }
        } else {
            PixelText(text: "—", scale: 7, color: .secondary)
            PixelText(text: stalledReason, scale: 2, color: Theme.warning)
        }
    }

    @ViewBuilder
    private func released(_ info: ReleaseInfo) -> some View {
        if info.launchDay == day {
            PixelText(text: "Launch day", scale: 4, color: Theme.pixelAccent)
            Text("Shipped \(GameCalendar(day: info.launchDay).longLabel)")
                .font(.caption)
                .foregroundStyle(Theme.pixelInk.opacity(0.7))
        } else {
            PixelText(text: "Day +\(day - info.launchDay)", scale: 5, color: Theme.pixelAccent)
            Text("Launched \(GameCalendar(day: info.launchDay).longLabel)")
                .font(.caption)
                .foregroundStyle(Theme.pixelInk.opacity(0.7))
        }
    }

    private var stalledReason: String {
        if engine.state.life.isAway(day: day) { return "Founder away" }
        if (eta?.crewCount ?? 0) == 0 { return "Nobody on the build" }
        return "Nothing moving"
    }

    private var accessibilityLabel: String {
        switch product.stage {
        case .development:
            if let days = eta?.daysToComplete {
                return days == 0
                    ? "Countdown: the build is done"
                    : "Countdown: \(days) day\(days == 1 ? "" : "s") to the ETA, \(GameCalendar(day: day + days).longLabel)"
            }
            return "Countdown: \(stalledReason.lowercased())"
        case .released(let info):
            return info.launchDay == day
                ? "Launch day"
                : "Day \(day - info.launchDay) since launch"
        }
    }
}

// MARK: - Whiteboard

/// The phase progress, who is on the build and what they land a day, and
/// the ship button once the gate is passed.
private struct WhiteboardPanel: View {
    let product: Product
    let progress: DevProgress
    let type: ProductTypeDef?
    let eta: BuildETA?
    let canShip: Bool
    let engine: GameEngine
    let onShip: () -> Void

    var body: some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack {
                    PixelSectionTitle(title: "Whiteboard")
                    Spacer(minLength: Theme.Spacing.sm)
                    if engine.state.economy.workPace != .normal {
                        WorkPacePill(pace: engine.state.economy.workPace)
                    }
                    StatPill(
                        systemImage: "ladybug.fill",
                        value: "\(progress.openBugs) bug\(progress.openBugs == 1 ? "" : "s")",
                        tint: progress.openBugs > 0 ? Theme.warning : .secondary
                    )
                }
                TriPhaseProgress(progress: progress, type: type)
                if let eta {
                    Text(crewLine(eta))
                        .font(Theme.Typography.number(.caption, weight: .regular))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button {
                    onShip()
                } label: {
                    Label("Ship it", systemImage: "shippingbox.fill")
                        .font(.system(.headline, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.xs)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(!canShip)
                .accessibilityLabel("Ship \(product.name)")
                if !canShip {
                    Text(
                        "Shipping unlocks once code reaches \(Int((engine.balance.shipCodeThreshold * 100).rounded()))% of its target."
                    )
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func crewLine(_ eta: BuildETA) -> String {
        guard eta.crewCount > 0 else { return "Nobody is on the build today." }
        let who = eta.crewCount == 1 ? "One person" : "\(eta.crewCount) people"
        return "\(who) on the build · +\(format(eta.designPerDay)) design, +\(format(eta.codePerDay)) code, +\(format(eta.polishPerDay)) polish a day"
    }

    private func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)).locale(Theme.gameLocale))
    }
}

// MARK: - Hype

/// The hype meter, what it buys at launch, and everything feeding it: the
/// campaigns on the build, the marketers on the crew, and the daily decay
/// eating at all of it.
private struct HypePanel: View {
    let product: Product
    let hype: Double
    let engine: GameEngine
    let onRoute: (Route) -> Void

    private var value: Int { Int(hype.rounded()) }

    private struct Feed: Identifiable {
        let id: String
        let systemImage: String
        let text: String
        var tint: Color = .secondary
    }

    var body: some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                PixelSectionTitle(title: "Hype")
                HStack(alignment: .lastTextBaseline, spacing: Theme.Spacing.md) {
                    PixelText(text: "\(value)", scale: 5, color: Theme.pixelAccent)
                        .id(value)
                        .animation(Theme.Motion.valueChange, value: value)
                    Text(worth)
                        .font(Theme.Typography.number(.caption, weight: .regular))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                meter
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    ForEach(feeds) { feed in
                        Label(feed.text, systemImage: feed.systemImage)
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(feed.tint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if !hasFeed {
                    Button {
                        Haptics.tap()
                        onRoute(.marketing)
                    } label: {
                        Label("Run a campaign", systemImage: "megaphone.fill")
                            .font(.footnote.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.accent)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Hype \(value). \(worth)")
    }

    /// The bar, in pixel chrome: a framed track with the fill on whole
    /// points. 100 is the top of the meter, as on the Marketing tab.
    private var meter: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle().fill(Theme.pixelInk.opacity(0.12))
                Rectangle()
                    .fill(Theme.pixelAccent)
                    .frame(width: max(0, proxy.size.width * min(max(hype / 100, 0), 1)))
            }
            .overlay { PixelPanelBorder(thickness: 2, corner: 2).fill(Theme.pixelInk.opacity(0.35)) }
        }
        .frame(height: 12)
        .animation(Theme.Motion.valueChange, value: hype)
        .accessibilityHidden(true)
    }

    /// The exchange rate the Marketing tab quotes, in the same arithmetic.
    private var worth: String {
        let balance = engine.balance
        let reviewPoints = hype / balance.reviewHypeDivisor
        let sales = hype * balance.hypeLaunchCarryFraction / balance.salesHypeDivisor * 100
        return "≈ +\(format(reviewPoints)) review pts, +\(format(sales))% sales at launch"
    }

    private var hasFeed: Bool {
        feeds.contains { $0.id != "decay" }
    }

    private var feeds: [Feed] {
        let state = engine.state
        let balance = engine.balance
        var rows: [Feed] = []
        for campaign in state.campaigns where campaign.productID == product.id {
            switch campaign.kindID {
            case "social_push" where campaign.endDay >= state.day:
                let left = campaign.endDay - state.day
                rows.append(Feed(
                    id: campaign.id.uuidString, systemImage: "megaphone.fill",
                    text: "Social push · +\(format(balance.socialPushDailyHype)) a day · "
                        + (left == 0 ? "last day" : "\(left) day\(left == 1 ? "" : "s") left"),
                    tint: Theme.positiveCash
                ))
            case "press_release" where state.day - campaign.endDay <= WarRoomOffer.windowDays:
                rows.append(Feed(
                    id: campaign.id.uuidString, systemImage: "newspaper.fill",
                    text: "Press release · landed \(GameCalendar(day: campaign.endDay).shortLabel)"
                ))
            case "launch_event" where state.day - campaign.endDay <= WarRoomOffer.windowDays:
                rows.append(Feed(
                    id: campaign.id.uuidString, systemImage: "party.popper.fill",
                    text: "Launch event · held \(GameCalendar(day: campaign.endDay).shortLabel)"
                ))
            default:
                continue
            }
        }
        let marketers = WarRoomScene.crew(of: product, state: state).filter { $0.role == .marketer }.count
        if marketers > 0 {
            rows.append(Feed(
                id: "marketers", systemImage: "person.2.fill",
                text: marketers == 1
                    ? "One marketer on the build adds hype every day"
                    : "\(marketers) marketers on the build add hype every day",
                tint: Theme.positiveCash
            ))
        }
        rows.append(Feed(
            id: "decay", systemImage: "arrow.down.right",
            text: "Fades \(Int((balance.hypeDecayRate * 100).rounded()))% a day until launch"
        ))
        return rows
    }

    private func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)).locale(Theme.gameLocale))
    }
}

// MARK: - Forecast

/// The ship forecast as a band: the projected review score filled in,
/// the crew's ceiling as a mark it cannot pass, and the thing holding it
/// down in the player's words. Reads live; the ticks move it.
private struct ForecastBand: View {
    let forecast: ShipForecast

    private var quality: Int { Int(forecast.quality.rounded()) }
    private var ceiling: Int { Int((forecast.crewCeiling * 100).rounded()) }

    var body: some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                PixelSectionTitle(title: "Forecast")
                HStack(alignment: .lastTextBaseline, spacing: Theme.Spacing.md) {
                    PixelText(text: "\(quality)", scale: 5, color: Theme.scoreTint(quality))
                        .id(quality)
                        .animation(Theme.Motion.valueChange, value: quality)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("if it shipped today")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(
                            forecast.codebaseCeiling < forecast.skillCeiling
                                ? "the codebase tops out at \(ceiling)"
                                : "the crew tops out at \(ceiling)"
                        )
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                    }
                }
                band
                if let limiting = forecast.limitingFactor {
                    Text(limiting)
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(
                            forecast.quality >= forecast.crewCeiling * 100 - 1 ? Theme.warning : .secondary
                        )
                        .fixedSize(horizontal: false, vertical: true)
                }
                if forecast.marketScale < 0.99 {
                    Label(
                        "Your own recent launches have taken \(Int(((1 - forecast.marketScale) * 100).rounded()))% of this launch's audience.",
                        systemImage: "chart.line.downtrend.xyaxis"
                    )
                    .font(.caption)
                    .foregroundStyle(Theme.warning)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Forecast: \(quality) out of 100 if shipped today, ceiling \(ceiling). \(forecast.limitingFactor ?? "")"
        )
    }

    /// 0 to 100 across the width: the score's fill, the ceiling's mark.
    private var band: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Rectangle().fill(Theme.pixelInk.opacity(0.12))
                Rectangle()
                    .fill(Theme.scoreTint(quality))
                    .frame(width: max(0, width * min(forecast.quality / 100, 1)))
                Rectangle()
                    .fill(Theme.pixelInk)
                    .frame(width: 3)
                    .offset(x: max(0, min(width - 3, width * min(forecast.crewCeiling, 1) - 1)))
            }
            .overlay { PixelPanelBorder(thickness: 2, corner: 2).fill(Theme.pixelInk.opacity(0.35)) }
        }
        .frame(height: 14)
        .animation(Theme.Motion.valueChange, value: forecast.quality)
        .accessibilityHidden(true)
    }
}

// MARK: - Launch day

/// The reveal, then the first week's numbers and the way back.
private struct LaunchDayPanel: View {
    let product: Product
    let release: ReleaseInfo
    let revealed: Int
    let typesOut: Bool
    let engine: GameEngine
    let onBack: () -> Void
    let onRoute: (Route) -> Void

    private var revealComplete: Bool { revealed >= release.reviews.count }

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            if release.reviews.isEmpty {
                CardView("The press", systemImage: "newspaper.fill") {
                    Text("Review copies are out. The verdicts land next week.")
                        .font(.subheadline)
                }
            } else {
                ReviewRevealList(
                    release: release, revealed: revealed, productID: product.id,
                    typesOut: typesOut, onRoute: onRoute
                )
            }
            if revealComplete {
                firstWeek
                    .transition(Theme.Motion.transition(.move(edge: .bottom).combined(with: .opacity)))
                Button {
                    Haptics.tap()
                    Sounds.play(.tap)
                    onBack()
                } label: {
                    Label("Back to the office", systemImage: "building.2.fill")
                        .font(.system(.headline, design: .rounded))
                }
                .buttonStyle(PixelButtonStyle())
                .accessibilityHint("Closes the war room")
            }
        }
    }

    /// The first sales week once it has posted; until then, the day it
    /// lands, with the clock running in the room to get there.
    private var firstWeek: some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                PixelSectionTitle(title: "First week")
                HStack(alignment: .top, spacing: Theme.Spacing.xl) {
                    if let first = release.weeklySales.first {
                        LaunchStat(label: "Revenue", value: first.revenue.money, tint: Theme.positiveCash)
                        LaunchStat(label: "Units", value: first.units.formatted(.number.locale(Theme.gameLocale)))
                        if release.isSubscription {
                            LaunchStat(
                                label: "Subscribers",
                                value: release.subscribers.formatted(.number.locale(Theme.gameLocale))
                            )
                        }
                    } else {
                        LaunchStat(
                            label: "Quality",
                            value: "\(Int(release.quality.rounded()))",
                            tint: Theme.scoreTint(Int(release.quality.rounded()))
                        )
                        LaunchStat(label: "Launch hype", value: "\(Int(release.hypeAtLaunch.rounded()))")
                    }
                }
                Text(firstWeekLine)
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if release.liveBugs > 0 {
                    Label(
                        "\(release.liveBugs) bug\(release.liveBugs == 1 ? "" : "s") already reported in the wild",
                        systemImage: "ladybug.fill"
                    )
                    .font(.footnote)
                    .foregroundStyle(Theme.warning)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var firstWeekLine: String {
        if let first = release.weeklySales.first {
            return "The first week on the market sold \(first.units.formatted(.number.locale(Theme.gameLocale))) for \(first.revenue.money)."
        }
        let posts = (release.launchDay / GameState.daysPerWeek + 1) * GameState.daysPerWeek
        let ramp = release.adoptionWeeks > 1.5
            ? " Word of mouth takes about \(Int(release.adoptionWeeks.rounded())) weeks to reach full speed."
            : ""
        return "The first week's numbers post on \(GameCalendar(day: posts).longLabel). Let the clock run.\(ramp)"
    }
}
