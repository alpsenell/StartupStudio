import SwiftUI
import TycoonEngine

// MARK: A3 (IPO day)

/// The exchange floor, in the war room's full-screen grammar: the room,
/// the board with your ticker on it, the bell, and the first day drawing
/// itself print by print. It plays once, between the tap that ends the run
/// and the founder biography behind it.
///
/// Everything drawn here is read off `IPOResult` — the engine priced the
/// offering and derived the pop before this view existed. The scene never
/// sends an action; the only thing it decides is when the ending card is
/// allowed to come up.
///
/// Reduce Motion: the whole scene is seated. Every beat is revealed at
/// once, no flash, no ringing, no drawing chart — the same frame the
/// animation ends on, with the same words under it.
struct IPOBellScreen: View {
    let companyName: String
    let founderName: String
    let result: IPOResult
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How far through the beats the scene is: 0 the empty floor, 1 the
    /// ticker on the board, 2 the bell rung, 3+ the chart, print by print.
    @State private var beat = 0
    @State private var started = false

    /// The prints of the first day, derived once.
    private var path: [Double] { result.dayOnePath() }

    /// The last beat: the ticker, the bell, and every print on the board.
    private var lastBeat: Int { 3 + path.count }

    private var revealedPrints: Int {
        guard beat > 2 else { return 0 }
        return min(path.count, beat - 2)
    }

    private var isDone: Bool { beat >= lastBeat }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                IPOBellContent(
                    companyName: companyName,
                    founderName: founderName,
                    result: result,
                    path: path,
                    beat: beat,
                    revealedPrints: revealedPrints
                )
                .padding(Theme.Spacing.lg)
            }
            footer
        }
        .gameColumn()
        .onAppear { startIfNeeded() }
    }

    // MARK: - Chrome

    private var topBar: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.sm) {
            Spacer().frame(width: 36)
            VStack(spacing: 3) {
                PixelText(
                    text: String(
                        localized: "IPO DAY",
                        comment: "Pixel title over the exchange-floor scene. Uppercase A-Z only — the bitmap font has no lowercase and no accents."
                    ),
                    scale: 2, color: Theme.pixelAccent, shadow: true
                )
                PixelText(
                    text: String(
                        localized: "DAY \(result.day)",
                        comment: "Pixel subtitle under the IPO scene's title: the game day the bell rang. Uppercase A-Z only."
                    ),
                    scale: 1, color: .secondary
                )
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("I P O day, day \(result.day)")
            Button {
                Haptics.tap()
                finish()
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Skip to the ending")
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var footer: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Button {
                Haptics.commit()
                finish()
            } label: {
                Text(isDone ? "The rest of the story" : "Skip the day")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PixelButtonStyle(fill: isDone ? Theme.pixelAccent : Theme.pixelPaper))
        }
        .padding(Theme.Spacing.lg)
        .background(.bar)
    }

    // MARK: - The beats

    private func startIfNeeded() {
        guard !started else { return }
        started = true
        guard !reduceMotion, !Theme.Motion.isReduced else {
            // The seated variant: the whole day, at once, already closed.
            beat = lastBeat
            return
        }
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            withAnimation(Theme.Motion.emphatic) { beat = 1 }  // the board
            Sounds.play(.tap)
            try? await Task.sleep(for: .milliseconds(700))
            withAnimation(Theme.Motion.emphatic) { beat = 2 }  // the bell
            Sounds.play(.ship)
            Haptics.success()
            try? await Task.sleep(for: .milliseconds(650))
            for tick in 1...path.count {
                try? await Task.sleep(for: .milliseconds(70))
                withAnimation(Theme.Motion.valueChange) { beat = 2 + tick }
            }
            beat = lastBeat
            Haptics.tap()
            Sounds.play(result.brokeOpen ? .warning : .cash)
        }
    }

    private func finish() {
        beat = lastBeat
        onFinish()
    }
}

// MARK: - The floor

/// The scene itself, taking its beat as a plain value so a preview (and a
/// screenshot pass) can draw any moment of the day it likes.
struct IPOBellContent: View {
    let companyName: String
    let founderName: String
    let result: IPOResult
    let path: [Double]
    let beat: Int
    let revealedPrints: Int

    /// The floor's figures stand still under Reduce Motion, the way the
    /// party room's do.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            board
            floor
            if revealedPrints > 0 { chart }
            if revealedPrints >= path.count { closingLines }
        }
    }

    // MARK: The board

    private var board: some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.md) {
                    PixelText(
                        text: beat >= 1 ? result.ticker : "    ",
                        scale: 5,
                        color: Theme.pixelInk,
                        shadow: true
                    )
                    Spacer(minLength: 0)
                    if revealedPrints > 0 {
                        PixelText(
                            text: moveLabel,
                            scale: 3,
                            color: currentMove < 0 ? Theme.negativeCash : Theme.positiveCash
                        )
                    }
                }
                Text(companyName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.pixelInk.opacity(0.7))
                Text("Offered at \(result.offerValuation.money) · \(result.price.displayName.lowercased())")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(Theme.pixelInk.opacity(0.7))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(result.ticker.map(String.init).joined(separator: " ")), \(companyName), "
                + "offered at \(result.offerValuation.money)."
        )
    }

    private var currentMove: Double {
        guard revealedPrints > 0 else { return 0 }
        return path[min(path.count - 1, revealedPrints - 1)]
    }

    private var moveLabel: String {
        let rounded = Int(currentMove.rounded())
        return "\(rounded >= 0 ? "+" : "")\(rounded)%"
    }

    // MARK: The room

    /// The floor: the hall, the desks, the rope, the bell over it all —
    /// and the exchange's own people standing on it.
    ///
    /// Iteration 18's review photographed the first pass and read it as a
    /// bar chart: an ink-block crowd on a pale wall, with the back desks
    /// rhyming with the outlet chips two screens earlier. The architecture
    /// is still `Canvas` blocks on a fixed 64×32 grid — but the wall is now
    /// dark and the windows light rather than the other way round, the
    /// floor has boards to stand on, and the crowd is `PixelFigure`, the
    /// same sprite the office and the party room draw. Nothing here invents
    /// a colour: the blocks are Theme's pixel tokens and the people carry
    /// PixelKit's master palette with them.
    private var floor: some View {
        ZStack(alignment: .bottom) {
            hall
            crowd
        }
        .frame(height: 190)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityHidden(true)
    }

    /// The room the crowd stands in: back wall, windows, banner, desks,
    /// podium, bell, and the boards under everyone's feet.
    private var hall: some View {
        Canvas(rendersAsynchronously: false) { context, size in
            // The blocks stay square and the room runs the full width of
            // its card: 32 rows set the unit, and the hall is as many
            // columns wide as the card holds. Fitting a fixed 64 columns
            // instead letterboxed the room — two pale slivers down the
            // sides, which is what a wall must not have.
            let unit = size.height / 32
            let columns = max(32, Int((size.width / unit).rounded(.up)))
            let middle = columns / 2
            func block(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ color: Color) {
                context.fill(
                    Path(
                        CGRect(
                            x: CGFloat(x) * unit, y: CGFloat(y) * unit,
                            width: CGFloat(w) * unit, height: CGFloat(h) * unit
                        )
                    ),
                    with: .color(color)
                )
            }
            let ink = Theme.pixelInk
            let paper = Theme.pixelPaper
            let accent = Theme.pixelAccent
            let rung = beat >= 2

            // The hall, dark: a lit room is read from its windows, and on
            // a pale wall the windows were the thing that disappeared.
            block(0, 0, columns, 32, ink.opacity(0.78))
            // The windows, in the wall rather than on it: a light pane, a
            // sill under it, and a mullion down the middle of each. They
            // skip the middle of the wall, which the banner hangs on.
            for column in stride(from: 2, to: columns - 8, by: 11)
            where column + 9 < middle - 8 || column > middle + 8 {
                block(column, 2, 7, 9, paper.opacity(0.92))
                block(column + 3, 2, 1, 9, ink.opacity(0.55))
                block(column, 6, 7, 1, ink.opacity(0.35))
                block(column - 1, 11, 9, 1, ink.opacity(0.45))
            }

            // The banner, strung the width of the hall the way a room is
            // dressed on a listing day. It carries no letters at this size
            // — the board above the scene is where the ticker is read. A
            // slab behind the bell instead of a strip across the wall read
            // as a monitor on a stand, which is the first thing this scene
            // must not look like.
            block(0, 12, columns, 2, accent.opacity(rung ? 0.95 : 0.72))
            for tab in stride(from: 2, to: columns, by: 9) {
                block(tab, 14, 2, 1, accent.opacity(rung ? 0.8 : 0.6))
            }

            // The desks along the back, their screens lit once it opens.
            for desk in stride(from: 1, to: columns - 8, by: 11)
            where desk + 8 < middle - 4 || desk > middle + 4 {
                block(desk, 15, 8, 5, ink.opacity(0.42))
                block(desk + 1, 16, 6, 2, rung ? accent.opacity(0.9) : paper.opacity(0.4))
                block(desk, 19, 8, 1, ink.opacity(0.6))
            }

            // The boards: a lit floor with its planks drawn across it, so
            // the people standing on it are standing on something.
            block(0, 20, columns, 12, paper.opacity(0.82))
            for plank in stride(from: 22, to: 32, by: 3) {
                block(0, plank, columns, 1, ink.opacity(0.1))
            }
            block(0, 20, columns, 1, ink.opacity(0.4))

            // The podium, the rope, and the bell above it.
            let drop = rung ? 0 : 1
            block(middle - 2, 2 + drop, 4, 4, accent)              // the bell
            block(middle - 3, 6 + drop, 6, 1, paper.opacity(0.9))  // its lip
            block(middle - 1, 7 + drop, 1, 4, paper.opacity(0.5))  // the pull rope
            block(middle - 3, 15, 6, 5, paper.opacity(0.72))       // the podium
            block(middle - 2, 16, 4, 2, ink.opacity(0.3))          // its front panel
            block(middle - 4, 14, 8, 1, paper.opacity(0.9))        // its top edge
            if rung {
                // The clang, drawn the only way a pixel room can: lines
                // leaving the bell.
                block(middle - 6, 3, 3, 1, accent.opacity(0.85))
                block(middle + 3, 3, 3, 1, accent.opacity(0.85))
                block(middle - 5, 6, 2, 1, accent.opacity(0.55))
                block(middle + 3, 6, 2, 1, accent.opacity(0.55))
            }
        }
    }

    /// The people on the floor. Seven of them, the same seven every time
    /// (the seeds are fixed, not drawn), sized so the hall reads as a room
    /// with a small crowd in it rather than a stadium of silhouettes. They
    /// cheer once the bell is rung.
    private var crowd: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(Array(Self.floorSeeds.enumerated()), id: \.offset) { index, seed in
                // Two ranks, staggered: the nearer people are taller and
                // stand lower, so seven figures read as a crowd with depth
                // rather than a chorus line.
                let near = index.isMultiple(of: 2)
                PixelFigure(
                    seed: seed,
                    pose: beat >= 2
                        ? (near ? .cheer : .chat)
                        : (near ? .chat : .standing),
                    height: near ? 56 : 46,
                    reduceMotion: reduceMotion
                )
                .frame(maxWidth: .infinity)
                .offset(y: near ? 0 : -9)
            }
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.bottom, 14)
    }

    /// Fixed, so the same seven people are on the floor in every
    /// screenshot and on every run — the room is the exchange's, not the
    /// player's, and a crowd that reshuffles reads as noise.
    private static let floorSeeds: [UInt64] = [11, 47, 3, 92, 26, 64, 5]

    // MARK: The first day

    private var chart: some View {
        let shown = Array(path.prefix(revealedPrints))
        let low = min(0, shown.min() ?? 0, result.pop)
        let high = max(0, shown.max() ?? 0, result.pop)
        return VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("The first day")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Canvas(rendersAsynchronously: false) { context, size in
                let span = max(1, high - low)
                func point(_ index: Int, _ value: Double) -> CGPoint {
                    CGPoint(
                        x: size.width * CGFloat(index) / CGFloat(max(1, path.count - 1)),
                        y: size.height * (1 - CGFloat((value - low) / span))
                    )
                }
                // The offer price: the line the day is measured against.
                var zero = Path()
                zero.move(to: point(0, 0))
                zero.addLine(to: CGPoint(x: size.width, y: point(0, 0).y))
                context.stroke(zero, with: .color(Theme.pixelInk.opacity(0.35)), lineWidth: 1)

                guard shown.count > 1 else { return }
                // Drawn as steps, because a pixel chart has no diagonals.
                var line = Path()
                line.move(to: point(0, shown[0]))
                for index in 1..<shown.count {
                    let next = point(index, shown[index])
                    line.addLine(to: CGPoint(x: next.x, y: line.currentPoint?.y ?? next.y))
                    line.addLine(to: next)
                }
                context.stroke(
                    line,
                    with: .color(currentMove < 0 ? Theme.negativeCash : Theme.positiveCash),
                    style: StrokeStyle(lineWidth: 3, lineJoin: .miter)
                )
            }
            .frame(height: 120)
            .padding(Theme.Spacing.sm)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("The first day's chart, closing \(result.popLabel).")
    }

    private var closingLines: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(headline)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(result.brokeOpen ? Theme.negativeCash : Theme.positiveCash)
                .fixedSize(horizontal: false, vertical: true)
            Text(
                // Second person, like the headline above it — and the
                // proceeds came out of the offer, not out of the close.
                "Close: \(result.dayOneClose.money) · \(result.proceeds.money) of the offer was yours."
            )
            .font(.callout)
            .monospacedDigit()
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headline: String {
        result.brokeOpen
            ? "\(result.ticker) broke open. It closed its first day at \(result.popLabel) — under the price you sold it at."
            : "\(result.ticker) closed its first day \(result.popLabel)."
    }
}

// MARK: - The screenshot pass

#if DEBUG
/// `-autoRoute a3-bell` / `a3-broken`: the floor on its own, with a made-up
/// listing, so the scene can be photographed without playing a run to an
/// IPO. Nothing in the game reads this, and a release build has none of it.
enum IPOBellDebug {
    static var fixture: IPOResult? {
        switch DebugLaunch.autoRouteName {
        case "a3-bell":
            IPOResult(
                price: .fair, ticker: "HALS", offerValuation: 3_011_474,
                proceeds: 602_295, pop: 36.3, dayOneClose: 4_105_318, day: 900
            )
        case "a3-broken":
            IPOResult(
                price: .aggressive, ticker: "MERL", offerValuation: 1_001_075,
                proceeds: 600_645, pop: -11.6, dayOneClose: 885_435, day: 400
            )
        default:
            nil
        }
    }
}
#endif
