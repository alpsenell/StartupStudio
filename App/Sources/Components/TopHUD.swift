import SwiftUI
import TycoonEngine

/// Persistent heads-up display: cash (left, with the delta that just moved
/// it underneath), the date and the runway (centre), the speed control
/// (right) — all in the game's bitmap face — with the notice rail under it.
///
/// Attached by each tab's root screen via `withTopHUD(engine:)` — inside
/// the tab's `NavigationStack`, on the stack's root content view — so the
/// root content is laid out below it and pushed destinations (which show
/// the navigation bar instead) are unaffected.
struct TopHUD: View {
    let engine: GameEngine

    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// See `GameShell.shared`: read optionally, because SwiftUI
    /// updates this property for presented content before the
    /// environment is installed and the non-optional form traps there.
    private var shell: GameShell { injectedShell ?? .shared }
    @Environment(AppRouter.self) private var router

    /// The sign colour the cash pill flashes when money moves, so the
    /// direction reads even when the delta's digits are not.
    @State private var cashFlash: Color?
    @State private var showingMoney = false
    // MARK: Iteration 10 — M5 (morning desk)
    @State private var showingDesk = false
    @Environment(\.gameSession) private var session
    // MARK: end of Iteration 10 — M5

    private var calendar: GameCalendar { engine.state.gameCalendar }

    var body: some View {
        VStack(spacing: 0) {
            bar
            NoticeRail(engine: engine) { route in router.go(route) }
        }
        .animation(Theme.Motion.entrance, value: engine.state.speed)
        .animation(Theme.Motion.entrance, value: shell.pendingReportWeek)
        // MARK: J1 (doors)
        // A person is playing this game: arm the four doors, once per
        // engine. The HUD is on every tab's root, so this runs whichever
        // tab the game opens on.
        .task(id: ObjectIdentifier(engine)) {
            if !engine.state.doors.armed { engine.send(.armDoors) }
        }
        // MARK: end J1
    }

    private var bar: some View {
        // One row rather than a centred overlay: at scale 2 the bitmap
        // date is wide enough to collide with the speed buttons if it is
        // free to sit dead centre. The cash and the speed control keep
        // their width; the date is the flexible one and falls back to its
        // compact form when the row is tight.
        // No spacers: the date column itself is the flexible member, so
        // `ViewThatFits` is offered everything the cash and the speed
        // control leave, not a third of it.
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                cashCounter
                CashDeltaSlot(engine: engine) { delta in flash(delta) }
            }
            .layoutPriority(1)

            VStack(alignment: .center, spacing: 3) {
                dateLabel
                runwayLabel
            }
            .padding(.top, 4)
            .frame(maxWidth: .infinity)

            SpeedControl(engine: engine, attention: needsAttention)
                .layoutPriority(1)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }

    /// Something is waiting on the player: the clock stopped for a reason,
    /// a report is unread, or a deferred question is counting down.
    private var needsAttention: Bool {
        !engine.lastPauseEvents.isEmpty
            || shell.pendingReportWeek != nil
            || shell.deferredChoiceID != nil
    }

    // MARK: - Date and runway

    /// "Mar W2 · Y1" with a weekend badge, or "W2 · Y1" when the row is
    /// too tight for the month — the badge folds into the compact form.
    private var dateLabel: some View {
        // MARK: Iteration 10 — M5 (morning desk): the date is the way back
        // to the desk from inside a run. A tap, a sheet, nothing else
        // about the HUD changes — and the desk never advances the clock.
        Button {
            Haptics.tap()
            showingDesk = true
        } label: {
            dateReadout
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens the morning desk")
        .sheet(isPresented: $showingDesk) {
            if let session {
                MorningDeskSheet(
                    session: session,
                    onOpen: { route in
                        showingDesk = false
                        router.go(route)
                    },
                    isAtFrontDoor: false,
                    onClose: { showingDesk = false }
                )
            }
        }
    }

    /// The date itself, as it has always been drawn.
    private var dateReadout: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Theme.Spacing.xs) {
                PixelText(text: calendar.hudLabel, scale: 2, color: .secondary)
                weekendBadge
            }
            HStack(spacing: Theme.Spacing.xs) {
                PixelText(text: calendar.compactHUDLabel, scale: 2, color: .secondary)
                weekendBadge
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(calendar.longLabel), week \(calendar.weekOfYear)\(calendar.isWeekend ? ", weekend" : "")"
        )
    }

    @ViewBuilder
    private var weekendBadge: some View {
        if calendar.isWeekend {
            Image(systemName: "sun.horizon.fill")
                .font(.caption2)
                .foregroundStyle(Theme.warning)
                .accessibilityLabel("Weekend")
        }
    }

    /// Runway is the number the game tells the player to watch, so it
    /// lives under the date rather than five cards down on HQ. Same
    /// thresholds as the burn card: orange under four weeks, red in debt.
    private var runwayLabel: some View {
        let cash = engine.state.company.cash
        let burn = engine.weeklyBurn
        let text: String
        let tint: Color
        if cash < 0 {
            text = String(localized: "IN THE RED", comment: "HUD runway readout when cash is negative. Bitmap face: A-Z, digits and a few symbols only, uppercase")
            tint = Theme.negativeCash
        } else if burn <= 0 {
            text = String(localized: "NO BURN", comment: "HUD runway readout when the company spends nothing. Bitmap face, uppercase")
            tint = Theme.positiveCash
        } else {
            let weeks = cash / burn
            text = String(localized: "RUNWAY \(weeks) WK", comment: "HUD runway readout: weeks of cash left. Bitmap face, uppercase")
            tint = weeks <= 4 ? Theme.warning : .secondary
        }
        return PixelText(text: text, scale: 1, color: tint)
            .accessibilityLabel(cash < 0 ? "In the red" : "Runway \(text.dropFirst(7))")
    }

    // MARK: - Cash

    /// The cash pill. The figure rolls when it changes — the pixel face's
    /// version of `.numericText()` — and tapping it opens the one screen
    /// where all the money is: company, bank and the founder's own.
    private var cashCounter: some View {
        let cash = engine.state.company.cash
        return Button {
            Haptics.tap()
            showingMoney = true
        } label: {
            ZStack {
                PixelText(
                    text: cash.money,
                    scale: 2,
                    color: cash < 0 ? Theme.negativeCash : Theme.pixelInk,
                    shadow: true
                )
                .id(cash)
                .transition(
                    Theme.Motion.transition(
                        .asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        )
                    )
                )
            }
            .clipped()
            .animation(Theme.Motion.valueChange, value: cash)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xs)
            .background(cashFlash ?? Theme.chipBackground, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Cash \(cash.money)")
        .accessibilityHint("Opens the money sheet")
        .sheet(isPresented: $showingMoney) {
            MoneySheet(engine: engine)
        }
    }

    private func flash(_ delta: Int) {
        let tint = (delta >= 0 ? Theme.positiveCash : Theme.negativeCash).opacity(0.28)
        withAnimation(.easeOut(duration: Theme.Motion.quick)) {
            cashFlash = tint
        }
        withAnimation(.easeIn(duration: Theme.Motion.value).delay(0.45)) {
            cashFlash = nil
        }
    }
}

extension View {
    /// Attach the persistent HUD as a top safe-area inset.
    ///
    /// Apply this to a tab's ROOT CONTENT VIEW (the `List`/`ScrollView`/
    /// `VStack` that is the `NavigationStack`'s root), never to the
    /// `NavigationStack` itself: an inset applied outside the stack isn't
    /// honored by pinned, non-scrolling content inside it (a header
    /// `VStack` above a `ScrollView` lands underneath the opaque HUD).
    /// Applied on the root content, everything in that view — pinned
    /// pickers included — is laid out below the HUD, and pushed
    /// destinations get the navigation bar instead.
    func withTopHUD(engine: GameEngine) -> some View {
        safeAreaInset(edge: .top, spacing: 0) { TopHUD(engine: engine) }
    }
}
