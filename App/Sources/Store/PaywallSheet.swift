import PixelKit
import SwiftUI
import TycoonContent
import TycoonEngine

// MARK: Iteration 7 — the unlock (R6)

/// The paywall, over the paused game: the office at night, the five
/// chapters as flags with the garage lit, the price in the game's own
/// hand, one button, Restore purchases, Not now. No countdown, nothing
/// "limited", nothing that would fail review or the game's tone.
struct PaywallSheet: View {
    let session: GameSession

    @State private var isBusy = false

    var body: some View {
        PaywallContent(
            scene: TitleScene.input(for: session.engine.state),
            companyName: session.engine.state.company.name,
            price: session.unlock.displayPrice,
            message: session.unlock.lastStoreMessage,
            isBusy: isBusy,
            onUnlock: {
                Haptics.tap()
                Sounds.play(.tap)
                Task {
                    isBusy = true
                    await session.purchaseUnlock()
                    isBusy = false
                }
            },
            onRestore: {
                Haptics.tap()
                Task {
                    isBusy = true
                    await session.restorePurchases()
                    isBusy = false
                }
            },
            onNotNow: {
                Haptics.tap()
                session.dismissPaywall()
            }
        )
        .task { await session.loadPriceIfNeeded() }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

/// The paywall as a function of plain values, so the snapshot suite can
/// draw it without a store.
struct PaywallContent: View {
    let scene: OfficeSceneInput
    let companyName: String
    /// The store's localized price; `nil` while it has not answered.
    let price: String?
    /// One line about the last attempt, if there was one.
    var message: String?
    var isBusy = false
    var onUnlock: () -> Void = {}
    var onRestore: () -> Void = {}
    var onNotNow: () -> Void = {}

    var body: some View {
        ScrollView {
            column
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Theme.screenBackground.ignoresSafeArea())
    }

    /// The sheet as one column, without the scroll view, so the snapshot
    /// suite can draw it (`ImageRenderer` draws nothing inside a
    /// `ScrollView`).
    var column: some View {
        VStack(spacing: Theme.Spacing.lg) {
            hero
            headline
            ChapterFlags(litThrough: 1)
            pitch
            priceBlock
            buttons
        }
        .padding(Theme.Spacing.lg)
    }

    /// The company's own office after hours, in the frame every scene has.
    private var hero: some View {
        PixelPanel(contentPadding: Theme.Spacing.sm) {
            OfficeSceneView(input: scene)
                .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("The \(scene.tier.rawValue) at night, the lights still on")
    }

    private var headline: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ViewThatFits(in: .horizontal) {
                PixelText(text: "The full company", scale: 3, color: Theme.pixelAccent)
                PixelText(text: "The full company", scale: 2, color: Theme.pixelAccent)
            }
            Text("The garage was free. \(companyName) has outgrown it.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var pitch: some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Every chapter after the garage — the loft, the studio, the scale-up and whatever it was all for — on this Apple ID, forever.")
                    .font(.body)
                    .foregroundStyle(Theme.pixelInk)
                    .fixedSize(horizontal: false, vertical: true)
                // MARK: P3 (purchases: surfaces and copy) — the spec's §6 line.
                Text("One purchase for the chapters. There is a small shop besides — a month of cash, a second chance after a bankruptcy, a fourth save, a few things for the flat — and nothing in it is needed to finish the game, and nothing bought reaches a leaderboard. Your save is exactly where you left it either way.")
                    .font(.footnote)
                    .foregroundStyle(Theme.pixelInk.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// The price in the bitmap face when the face can draw it — "$4.99"
    /// — and in the system number face at the same weight when it cannot
    /// ("€4,99", "4,99 €", a non-breaking space): a storefront's price
    /// is the one string on this screen the game did not write, and a
    /// hollow box where the currency should be is not a price.
    @ViewBuilder
    private var priceBlock: some View {
        if let price {
            if PixelFont.canDraw(price) {
                PixelText(text: price, scale: 3, color: Theme.pixelInk, shadow: true)
                    .accessibilityLabel("Price: \(price)")
            } else {
                Text(price)
                    .font(Theme.Typography.number(.title, weight: .bold))
                    .foregroundStyle(Theme.pixelInk)
                    .accessibilityLabel("Price: \(price)")
            }
        } else {
            Text("Asking the App Store for the price…")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Asking the App Store for the price")
        }
    }

    private var buttons: some View {
        VStack(spacing: Theme.Spacing.md) {
            Button(action: onUnlock) {
                Text(price.map { "Unlock the company · \($0)" } ?? "Unlock the company")
                    .font(.system(.headline, design: .rounded))
                    .multilineTextAlignment(.center)
            }
            .buttonStyle(PixelButtonStyle())
            .disabled(isBusy)
            .accessibilityHint("Buys every chapter after the garage")

            if let message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Theme.warning)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(Theme.Motion.transition(.opacity))
            }

            Button(action: onRestore) {
                Label("Restore purchases", systemImage: "arrow.clockwise")
                    .font(.system(.subheadline, design: .rounded))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(Theme.accent)
            .disabled(isBusy)
            .accessibilityHint("Asks the App Store for a purchase made on another device")

            Button(action: onNotNow) {
                Text("Not now")
                    .font(.system(.subheadline, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.xs)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(isBusy)
            .accessibilityHint("Back to the paused game. Nothing is lost.")
        }
        .animation(Theme.Motion.entrance, value: message)
    }
}

// MARK: - Flags

/// The five chapters as pennants on a line: the ones the run has reached
/// are lit in the accent, the rest wait in outline. They bob a pixel on
/// the breeze unless the player has asked for less motion.
struct ChapterFlags: View {
    /// The last chapter that is lit — 1 on the paywall, the garage.
    let litThrough: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    private var chapters: [Int] { Array(1...ProgressionState.chapterCount) }

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.25, paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    ForEach(chapters, id: \.self) { chapter in
                        flag(chapter, time: t)
                    }
                }
            } else {
                HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                    ForEach(chapters, id: \.self) { chapter in
                        flag(chapter, time: t)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private func flag(_ chapter: Int, time: TimeInterval) -> some View {
        let lit = chapter <= litThrough
        // Each flag on its own phase, a whole pixel at a time: 0, -1, -2.
        let bob = lit || reduceMotion ? 0 : CGFloat((Int((time * 2 + Double(chapter) * 0.9).truncatingRemainder(dividingBy: 3)) % 3) - 1)
        return VStack(spacing: 2) {
            PennantShape()
                .fill(lit ? Theme.pixelAccent : Theme.pixelPaper)
                .overlay {
                    PennantShape()
                        .stroke(lit ? Theme.pixelAccent : Theme.pixelInk.opacity(0.5), lineWidth: 2)
                }
                .frame(width: 30, height: 18)
                .offset(y: bob)
            Rectangle()
                .fill(Theme.pixelInk.opacity(0.6))
                .frame(width: 2, height: 10)
            Text(ChapterDef.title(for: chapter))
                .font(.system(.caption2, design: .rounded).weight(lit ? .bold : .regular))
                .foregroundStyle(lit ? Theme.pixelAccent : Color.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private var accessibilityLabel: String {
        let names = chapters.map { chapter in
            "\(ChapterDef.title(for: chapter))\(chapter <= litThrough ? ", played" : "")"
        }
        return "Chapters: " + names.joined(separator: ", ")
    }
}

/// A swallow-tailed pennant on whole pixels.
struct PennantShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let notch = rect.width * 0.25
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - notch, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Restore, in Settings

/// The Settings row: `AppStore.sync()` behind a tap, and the outcome as
/// an alert. Here rather than in `SettingsSheet` so StoreKit stays under
/// `Store/` and the sheet's diff is one line.
struct RestorePurchasesRow: View {
    @Environment(\.gameSession) private var session
    @State private var isBusy = false
    @State private var outcome: String?

    var body: some View {
        Button {
            guard let session, !isBusy else { return }
            Task {
                isBusy = true
                let entitled = await session.restorePurchases()
                isBusy = false
                outcome = entitled
                    ? "The full company is yours on this Apple ID."
                    : (session.unlock.lastStoreMessage ?? "No purchase to restore on this Apple ID.")
            }
        } label: {
            HStack {
                Label("Restore purchases", systemImage: "arrow.clockwise")
                Spacer()
                if isBusy {
                    ProgressView()
                } else if session?.unlock.isEntitled == true {
                    Text("Owned")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .disabled(isBusy || session == nil)
        .alert("Restore purchases", isPresented: Binding(
            get: { outcome != nil },
            set: { presented in if !presented { outcome = nil } }
        )) {
            Button("OK") { outcome = nil }
        } message: {
            Text(outcome ?? "")
        }
    }
}

// MARK: - Preview

#Preview("Paywall") {
    PaywallContent(
        scene: TitleScene.emptyGarage,
        companyName: "Northgate Softworks",
        price: "$4.99"
    )
}
