import SwiftUI
import TycoonEngine

/// The room itself: a backdrop, a table, the person behind it, and the
/// last thing they said.
///
/// Deliberately free of the sheet's navigation chrome, like
/// `NetworkingFloorView` — it is the half of the screen worth looking at,
/// and `ImageRenderer` draws a `NavigationStack` as a "no entry"
/// placeholder rather than the view inside it.
struct PitchTableView: View {
    let counterpart: PitchCounterpart
    let seed: UInt64
    /// The opener, or the last line back.
    let line: String
    /// Whether the last exchange landed. `nil` before the first one.
    let landed: Bool?
    /// −100…100.
    let warmth: Double
    /// The body language, while the want is still hidden.
    var tell: String?

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                LinearGradient(
                    colors: PitchLook.gradient(counterpart),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(edges: .horizontal)

                // The figure sits behind the table, so the room reads as
                // a meeting rather than two people standing in a gradient.
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    PixelFigure(
                        seed: seed,
                        isFounder: false,
                        pose: warmth >= 20 ? .chat : .standing,
                        height: min(120, geometry.size.height * 0.46)
                    )
                    .padding(.bottom, -18)
                    PitchTable(tint: PitchLook.gradient(counterpart).last ?? .black)
                        .frame(height: max(28, geometry.size.height * 0.20))
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    PitchWarmthBar(warmth: warmth, counterpart: counterpart)
                    if !line.isEmpty {
                        PitchSpokenLine(text: line, landed: landed)
                    }
                    if let tell {
                        HStack(alignment: .top, spacing: Theme.Spacing.xs) {
                            Image(systemName: "eye.fill")
                                .font(.caption2)
                                .padding(.top, 2)
                            Text(tell)
                                .font(.caption)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .foregroundStyle(.white.opacity(0.7))
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(Theme.Spacing.lg)
            }
        }
    }
}

/// The table: a slab with a highlight along its front edge, in the room's
/// own colour. Cheaper than a sprite and it sits under any figure.
private struct PitchTable: View {
    let tint: Color

    var body: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.95), .black.opacity(0.65)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            Rectangle()
                .fill(.white.opacity(0.16))
                .frame(height: 2)
        }
        .allowsHitTesting(false)
    }
}

/// How the room is going, as a bar that fills from the middle out — the
/// centre is the paper as written, and both directions are real.
struct PitchWarmthBar: View {
    let warmth: Double
    let counterpart: PitchCounterpart

    private var band: PitchBand { PitchRoom.band(warmth) }

    private var tint: Color {
        band.isGood ? Theme.positiveCash : (band.isBad ? Theme.negativeCash : .white.opacity(0.7))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(counterpart.displayName.uppercased())
                    .font(.caption2.weight(.bold))
                    .kerning(0.8)
                    .foregroundStyle(.white.opacity(0.7))
                Spacer(minLength: 0)
                Text(band.displayName)
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
            }
            GeometryReader { geometry in
                let half = geometry.size.width / 2
                let extent = min(half, half * abs(warmth) / PitchRoom.warmthLimit)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.black.opacity(0.35))
                    Capsule()
                        .fill(tint)
                        .frame(width: max(extent, warmth == 0 ? 0 : 2))
                        .offset(x: warmth >= 0 ? half : half - extent)
                    Rectangle()
                        .fill(.white.opacity(0.5))
                        .frame(width: 1)
                        .offset(x: half)
                }
            }
            .frame(height: 8)
            .animation(Theme.Motion.valueChange, value: warmth)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("The room is \(band.displayName.lowercased())")
    }
}

/// What they just said, over the table. One line at a time — a chat log
/// would turn the room into a transcript.
private struct PitchSpokenLine: View {
    let text: String
    let landed: Bool?

    var body: some View {
        Text(text)
            .font(.callout.italic())
            .foregroundStyle(.white)
            .shadow(radius: 3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.black.opacity(0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(borderTint, lineWidth: 1)
                    )
            )
            .transition(.opacity)
            .animation(Theme.Motion.valueChange, value: text)
    }

    private var borderTint: Color {
        switch landed {
        case true: Theme.positiveCash.opacity(0.6)
        case false: Theme.negativeCash.opacity(0.6)
        case nil: Color.white.opacity(0.15)
        }
    }
}
