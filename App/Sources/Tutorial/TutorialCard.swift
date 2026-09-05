import SwiftUI
import TycoonEngine

// MARK: Iteration 7 — the first hour (R1)

/// The tour's card, drawn above the tab bar: the beat's bitmap kicker,
/// its line, one button that goes where the beat points, and *Skip the
/// tour*. Pixel paper, like the decision sheet, because it is the game
/// talking — not a system banner.
struct TutorialCard: View {
    let beat: TutorialBeat
    let onAction: () -> Void
    let onSkip: () -> Void

    var body: some View {
        PixelPanel(contentPadding: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(spacing: Theme.Spacing.sm) {
                    PixelText(text: beat.step.title, scale: 2, color: Theme.pixelAccent, shadow: true)
                    Spacer(minLength: 0)
                    Text("\(beat.step.rawValue + 1)/\(TutorialStep.allCases.count)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Theme.pixelInk.opacity(0.6))
                        .accessibilityLabel("Beat \(beat.step.rawValue + 1) of \(TutorialStep.allCases.count)")
                }
                Text(beat.body)
                    .font(.subheadline)
                    .foregroundStyle(Theme.pixelInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                buttons
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tour: \(beat.step.title)")
    }

    /// The action beside the skip at regular sizes, over it once the type
    /// is large enough that they no longer share a line.
    private var buttons: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Theme.Spacing.md) {
                actionButton
                skipButton
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                actionButton
                skipButton
            }
        }
    }

    private var actionButton: some View {
        Button {
            Haptics.tap()
            Sounds.play(.tap)
            onAction()
        } label: {
            Text(beat.buttonLabel)
                .font(.subheadline.weight(.bold))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .buttonStyle(PixelButtonStyle())
    }

    private var skipButton: some View {
        Button {
            Haptics.tap()
            Sounds.play(.tap)
            onSkip()
        } label: {
            Text("Skip the tour")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.pixelInk.opacity(0.7))
                .padding(.horizontal, Theme.Spacing.sm)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressableRow)
        .fixedSize()
        .accessibilityHint("Ends the tour and opens every tab")
    }
}

// MARK: - Wiring

/// Hangs the card under a tab's content, above the tab bar. Applied to
/// each tab root rather than the `TabView`, because an inset on the
/// `TabView` itself lands over the bar.
struct TutorialCardInset: ViewModifier {
    let session: GameSession
    let engine: GameEngine

    @Environment(AppRouter.self) private var router
    @Environment(GameShell.self) private var shell

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let step = session.tutorial?.activeStep {
                    let beat = TutorialScript.beat(for: step, state: engine.state)
                    TutorialCard(
                        beat: beat,
                        onAction: { perform(beat.action, step: step) },
                        onSkip: { session.skipTour() }
                    )
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.sm)
                    .padding(.bottom, Theme.Spacing.xs)
                    .background(Theme.screenBackground.opacity(0.92))
                    .transition(Theme.Motion.transition(.move(edge: .bottom).combined(with: .opacity)))
                    .id(step)
                }
            }
            .animation(Theme.Motion.weighted, value: session.tutorial?.activeStep)
    }

    private func perform(_ action: TutorialAction, step: TutorialStep) {
        switch action {
        case .next:
            session.advanceTour(from: step)
        case .route(let route):
            router.go(route)
        case .play:
            engine.setSpeed(.x1)
        case .openReport:
            shell.openWeeklyReport(engine: engine, byHand: false)
        }
    }
}

/// The once-per-root wiring: starts or resumes the tour when the engine
/// changes, follows each beat to the tab it opens, lets a route open a
/// tab the tour has not reached yet, and moves the welcome on after four
/// seconds.
struct TutorialTourRoot: ViewModifier {
    let session: GameSession
    let engine: GameEngine

    @Environment(AppRouter.self) private var router
    @Environment(GameShell.self) private var shell

    func body(content: Content) -> some View {
        content
            .onChange(of: ObjectIdentifier(engine), initial: true) { _, _ in
                session.tourEngineChanged(shell: shell)
                settle()
            }
            .onChange(of: session.tutorial?.step) { _, step in
                if let tab = step?.opensTab { router.tab = tab }
                settle()
            }
            // A route into a tab the tour has not opened — the Now card
            // sending the player to hire — opens it: the player found it,
            // and a selection the bar cannot show would leave the screen blank.
            .onChange(of: router.tab) { _, tab in
                session.tourReached(tab)
            }
            .task(id: session.tutorial?.step) {
                guard session.tutorial?.activeStep == .welcome,
                      DebugLaunch.launchTourBeat == nil
                else { return }
                try? await Task.sleep(for: .seconds(4))
                guard !Task.isCancelled else { return }
                session.advanceTour(from: .welcome)
            }
    }

    /// Keeps the selection on a tab the bar draws.
    private func settle() {
        guard let visible = session.tutorial?.visibleTabs, !visible.contains(router.tab) else { return }
        router.tab = .hq
    }
}

extension View {
    func tutorialCardInset(session: GameSession, engine: GameEngine) -> some View {
        modifier(TutorialCardInset(session: session, engine: engine))
    }

    func tutorialTourRoot(session: GameSession, engine: GameEngine) -> some View {
        modifier(TutorialTourRoot(session: session, engine: engine))
    }
}

#Preview {
    VStack {
        Spacer()
        TutorialCard(
            beat: TutorialScript.beat(
                for: .hire,
                state: GameEngine.newGame(
                    companyName: "Northgate", seed: 1, difficulty: .normal,
                    founder: FounderProfile(name: "Mira", archetype: .hacker)
                ).state
            ),
            onAction: {},
            onSkip: {}
        )
        .padding()
    }
    .background(Theme.screenBackground)
}
