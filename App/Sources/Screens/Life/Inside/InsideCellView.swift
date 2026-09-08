import PixelKit
import SwiftUI
import TycoonEngine

/// Iteration 11, wave two — W4. The cell: a wall, a window with a bar
/// across it, two people and a bunk.
///
/// Drawn the way `CrimeBenchView` draws the courtroom and `PitchTableView`
/// draws the pitch: a flat backdrop, pixel figures standing on a floor
/// line, and one line of what somebody just said over the top. Free of
/// navigation chrome, because it is the half of the screen worth looking
/// at.
struct InsideCellView: View {
    let founderSeed: UInt64
    let cellmateSeed: UInt64
    let cellmateName: String
    /// The last line of the log.
    let line: String
    /// Days served and days handed down, for the scratches on the wall.
    let served: Int
    let total: Int

    private static let wall = [
        Color(red: 0.13, green: 0.14, blue: 0.16),
        Color(red: 0.26, green: 0.27, blue: 0.29),
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                LinearGradient(colors: Self.wall, startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea(edges: .horizontal)

                // The window: high, small, and barred.
                VStack {
                    HStack {
                        Spacer(minLength: 0)
                        InsideWindow()
                            .frame(width: 76, height: 52)
                            .padding(.trailing, Theme.Spacing.xl)
                            .padding(.top, 96)
                    }
                    Spacer(minLength: 0)
                }

                // The tally on the wall, one scratch a week.
                VStack {
                    HStack(alignment: .top) {
                        InsideTally(weeks: max(0, served / 7))
                            .padding(.leading, Theme.Spacing.lg)
                            .padding(.top, 104)
                        Spacer(minLength: 0)
                    }
                    Spacer(minLength: 0)
                }

                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    HStack(alignment: .bottom, spacing: 26) {
                        PixelFigure(
                            seed: founderSeed,
                            isFounder: true,
                            pose: .standing,
                            height: min(132, geometry.size.height * 0.46)
                        )
                        if cellmateSeed != 0 {
                            PixelFigure(
                                seed: cellmateSeed,
                                isFounder: false,
                                pose: .chat,
                                height: min(120, geometry.size.height * 0.42)
                            )
                            .opacity(0.9)
                        }
                    }
                    .padding(.bottom, -10)
                    InsideBunk(caption: cellmateName.isEmpty ? "" : "\(cellmateName), top bunk")
                        .frame(height: max(30, geometry.size.height * 0.20))
                }

                // The line sits at the top, the way the courtroom's does:
                // the figures are the bottom half of the picture and a
                // caption across their faces is a caption across the art.
                if !line.isEmpty {
                    VStack {
                        InsideSpokenLine(text: line)
                            .padding(Theme.Spacing.lg)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            cellmateName.isEmpty
                ? "A cell. Day \(served) of \(total)."
                : "A cell shared with \(cellmateName). Day \(served) of \(total)."
        )
    }
}

/// A small barred window with a grey sky behind it.
private struct InsideWindow: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(LinearGradient(
                    colors: [Color(red: 0.55, green: 0.60, blue: 0.66), Color(red: 0.35, green: 0.40, blue: 0.46)],
                    startPoint: .top, endPoint: .bottom
                ))
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    Rectangle().fill(Color.black.opacity(0.75)).frame(width: 4)
                }
            }
            Rectangle()
                .strokeBorder(Color.black.opacity(0.6), lineWidth: 4)
        }
        .allowsHitTesting(false)
    }
}

/// Four scratches and a line through them, once a week.
private struct InsideTally: View {
    let weeks: Int

    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            ForEach(0..<min(weeks, 10), id: \.self) { index in
                ZStack {
                    Rectangle()
                        .fill(Color.white.opacity(0.32))
                        .frame(width: 2, height: 18)
                    if index % 5 == 4 {
                        Rectangle()
                            .fill(Color.white.opacity(0.32))
                            .frame(width: 16, height: 2)
                            .rotationEffect(.degrees(-20))
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// The bunk the room stands on, with the name of whoever has the top one.
private struct InsideBunk: View {
    let caption: String

    var body: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(LinearGradient(
                    colors: [Color(red: 0.22, green: 0.23, blue: 0.26), .black.opacity(0.8)],
                    startPoint: .top, endPoint: .bottom
                ))
            Rectangle()
                .fill(Color(red: 0.52, green: 0.54, blue: 0.58).opacity(0.5))
                .frame(height: 2)
            if !caption.isEmpty {
                Text(caption.uppercased())
                    .font(.caption2.weight(.bold))
                    .kerning(1.2)
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.top, 8)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, Theme.Spacing.lg)
            }
        }
        .allowsHitTesting(false)
    }
}

/// The last line of the log, over the room. One at a time.
private struct InsideSpokenLine: View {
    let text: String

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
                    .fill(.black.opacity(0.42))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                    )
            )
            .transition(.opacity)
            .animation(Theme.Motion.valueChange, value: text)
    }
}
