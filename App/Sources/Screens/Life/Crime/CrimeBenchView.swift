import SwiftUI
import TycoonEngine

/// Iteration 11 — N1. The room itself: a panelled wall, a bench, the
/// judge behind it, the prosecutor at her table, and the last thing said.
///
/// The pitch room's `PitchTableView` turned round — there the founder is
/// selling across one table, here they are being asked questions from a
/// height. Free of navigation chrome for the same reason the pitch table
/// is: it is the half of the screen worth looking at.
struct CrimeBenchView: View {
    let seed: UInt64
    /// The last thing said across the room.
    let line: String
    /// Whether the last exchange landed. `nil` before the first one.
    let landed: Bool?
    /// −100…100. Below zero the bench is against you.
    let standing: Double
    /// What the standing currently reads as: "Fine", "Custodial".
    let verdictWord: String
    /// What the room is about, for the plaque under the bench.
    let charge: String

    private static let panel = [
        Color(red: 0.16, green: 0.13, blue: 0.11),
        Color(red: 0.32, green: 0.24, blue: 0.18),
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                LinearGradient(colors: Self.panel, startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea(edges: .horizontal)

                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    HStack(alignment: .bottom, spacing: 22) {
                        // The prosecutor stands at her table, lower and to
                        // the side; the judge is the one you are talking to.
                        PixelFigure(
                            seed: seed &* 31,
                            isFounder: false,
                            pose: .standing,
                            height: min(104, geometry.size.height * 0.36)
                        )
                        .opacity(0.85)
                        PixelFigure(
                            seed: seed,
                            isFounder: false,
                            pose: standing >= 20 ? .chat : .standing,
                            height: min(140, geometry.size.height * 0.50)
                        )
                    }
                    .padding(.bottom, -14)
                    CrimeBench(charge: charge)
                        .frame(height: max(34, geometry.size.height * 0.22))
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    CrimeStandingBar(standing: standing, word: verdictWord)
                    if !line.isEmpty {
                        CrimeSpokenLine(text: line, landed: landed)
                    }
                }
                .padding(Theme.Spacing.lg)
            }
        }
    }
}

/// The bench: a heavy slab with a brass line along the front and the
/// charge on a plaque, because a courtroom labels itself.
private struct CrimeBench: View {
    let charge: String

    var body: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.30, green: 0.22, blue: 0.16),
                            .black.opacity(0.72),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            Rectangle()
                .fill(Color(red: 0.82, green: 0.68, blue: 0.38).opacity(0.55))
                .frame(height: 2)
            Text(charge.uppercased())
                .font(.caption2.weight(.bold))
                .kerning(1.2)
                .foregroundStyle(.white.opacity(0.45))
                .padding(.top, 10)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, Theme.Spacing.lg)
        }
        .allowsHitTesting(false)
    }
}

/// How the hearing is going, as a bar that fills from the middle out. The
/// centre is where a founder walks in with a clean defence and no paper
/// against them; both directions are real, and the word above it is the
/// verdict the engine would deliver right now.
struct CrimeStandingBar: View {
    let standing: Double
    let word: String

    private var tint: Color {
        switch standing {
        case 42...: Theme.positiveCash
        case 4..<42: Theme.warning
        case -34..<4: Color.orange
        default: Theme.negativeCash
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("THE BENCH")
                    .font(.caption2.weight(.bold))
                    .kerning(0.8)
                    .foregroundStyle(.white.opacity(0.7))
                Spacer(minLength: 0)
                Text(word)
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
            }
            GeometryReader { geometry in
                let half = geometry.size.width / 2
                let extent = min(half, half * abs(standing) / Crime.standingLimit)
                ZStack(alignment: .leading) {
                    Capsule().fill(.black.opacity(0.4))
                    Capsule()
                        .fill(tint)
                        .frame(width: max(extent, standing == 0 ? 0 : 2))
                        .offset(x: standing >= 0 ? half : half - extent)
                    Rectangle()
                        .fill(.white.opacity(0.5))
                        .frame(width: 1)
                        .offset(x: half)
                }
            }
            .frame(height: 8)
            .animation(Theme.Motion.valueChange, value: standing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("The bench: \(word)")
    }
}

/// What was just said, over the room. One line at a time — a transcript
/// would turn a hearing into a chat log.
private struct CrimeSpokenLine: View {
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
                    .fill(.black.opacity(0.4))
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
