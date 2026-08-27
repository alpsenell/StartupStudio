import SwiftUI
import TycoonEngine

/// Persistent heads-up display: cash (left), the calendar date (center),
/// speed control (right) — all in the game's bitmap face — with the
/// weekly-report chip, the pause banner and the coach tip stacked under it.
///
/// Attached by each tab's root screen via `withTopHUD(engine:)` — inside
/// the tab's `NavigationStack`, on the stack's root content view — so the
/// root content is laid out below it and pushed destinations (which show
/// the navigation bar instead) are unaffected.
struct TopHUD: View {
    let engine: GameEngine

    @Environment(GameShell.self) private var shell
    @Environment(AppRouter.self) private var router

    private var calendar: GameCalendar { engine.state.gameCalendar }

    var body: some View {
        VStack(spacing: 0) {
            bar
            WeeklyReportChip(engine: engine)
            PauseBanner(engine: engine) { route in router.go(route) }
            TipStrip(engine: engine) { route in router.go(route) }
        }
        .animation(.spring(duration: 0.3), value: engine.state.speed)
        .animation(.spring(duration: 0.3), value: shell.pendingReportWeek)
    }

    private var bar: some View {
        ZStack {
            dateLabel

            HStack {
                cashCounter
                Spacer()
                SpeedControl(engine: engine)
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
        .overlay(alignment: .topLeading) {
            CashDeltaOverlay(engine: engine)
                .padding(.leading, Theme.Spacing.lg)
                .padding(.top, 30)
        }
    }

    /// "Mar W2 · Y1", with a weekend badge on Saturday and Sunday.
    private var dateLabel: some View {
        HStack(spacing: Theme.Spacing.xs) {
            PixelText(text: calendar.hudLabel, scale: 2, color: .secondary)
            if calendar.isWeekend {
                Image(systemName: "sun.horizon.fill")
                    .font(.caption2)
                    .foregroundStyle(Theme.warning)
                    .accessibilityLabel("Weekend")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(calendar.longLabel), week \(calendar.weekOfYear)\(calendar.isWeekend ? ", weekend" : "")"
        )
    }

    private var cashCounter: some View {
        let cash = engine.state.company.cash
        return PixelText(
            text: cash.money,
            scale: 2,
            color: cash < 0 ? Theme.negativeCash : Theme.pixelInk,
            shadow: true
        )
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
        .background(Theme.chipBackground, in: Capsule())
        .accessibilityLabel("Cash \(cash.money)")
    }
}

/// The "Week 12 report" chip: non-blocking, appears at each week's end and
/// stays until the player reads it.
private struct WeeklyReportChip: View {
    let engine: GameEngine

    @Environment(GameShell.self) private var shell

    var body: some View {
        if let week = shell.pendingReportWeek {
            Button {
                shell.openWeeklyReport(engine: engine)
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.footnote.weight(.bold))
                    Text("Week \(week) report")
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.sm)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.accent)
            .background(Theme.accent.opacity(0.10))
            .overlay(alignment: .bottom) { Divider() }
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityHint("Opens the weekly report")
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
