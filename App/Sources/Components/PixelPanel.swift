import SwiftUI

/// A 9-slice pixel border: a chunky outer frame, a 1-pixel inner highlight
/// and a shadowed bottom-right, drawn on whole pixels so it matches the
/// sprites it wraps.
///
/// Used around the cards that contain a pixel scene (office, home, city)
/// and around the sheets built out of pixel chrome, so the art has a frame
/// instead of floating in an iOS grouped list.
struct PixelPanelBorder: Shape {
    /// Thickness of the frame in points. Keep it a multiple of the pixel
    /// scale (3 or 6) so the border lands on pixel boundaries.
    var thickness: CGFloat = 3
    /// Size of the mitred corner notch, in the same units.
    var corner: CGFloat = 3

    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Outer ring minus the four corner pixels: a pixel frame is
        // square-cornered but "chipped", which reads as hand-placed pixels
        // rather than a rounded system stroke.
        path.addRect(CGRect(x: corner, y: 0, width: rect.width - corner * 2, height: thickness))
        path.addRect(
            CGRect(
                x: corner, y: rect.height - thickness,
                width: rect.width - corner * 2, height: thickness
            )
        )
        path.addRect(CGRect(x: 0, y: corner, width: thickness, height: rect.height - corner * 2))
        path.addRect(
            CGRect(
                x: rect.width - thickness, y: corner,
                width: thickness, height: rect.height - corner * 2
            )
        )
        // The chipped corners themselves.
        for point in [
            CGPoint(x: corner, y: corner),
            CGPoint(x: rect.width - corner - thickness, y: corner),
            CGPoint(x: corner, y: rect.height - corner - thickness),
            CGPoint(x: rect.width - corner - thickness, y: rect.height - corner - thickness),
        ] {
            path.addRect(CGRect(origin: point, size: CGSize(width: thickness, height: thickness)))
        }
        return path
    }
}

/// Container that draws its content on pixel paper inside a 9-slice pixel
/// border.
struct PixelPanel<Content: View>: View {
    /// Fill behind the content.
    var paper: Color = Theme.pixelPaper
    /// Border ink.
    var ink: Color = Theme.pixelInk
    /// Border thickness in points.
    var thickness: CGFloat = 3
    /// Padding between the border and the content.
    var contentPadding: CGFloat = Theme.Spacing.md

    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(contentPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(paper)
            .overlay {
                PixelPanelBorder(thickness: thickness, corner: thickness)
                    .fill(ink)
            }
            .overlay(alignment: .topLeading) {
                // Inner highlight along the top/left, shadow bottom/right:
                // the standard two-tone bevel of a pixel UI panel.
                Rectangle()
                    .fill(Color.white.opacity(0.16))
                    .frame(height: thickness / 3 + 1)
                    .padding(.horizontal, thickness)
                    .padding(.top, thickness)
            }
            .compositingGroup()
    }
}

/// A pixel-chrome heading: small caps bitmap title with a rule under it.
struct PixelSectionTitle: View {
    let title: String
    var tint: Color = Theme.pixelAccent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            PixelText(text: title, scale: 2, color: tint)
            Rectangle()
                .fill(tint.opacity(0.4))
                .frame(height: 2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    VStack(spacing: 16) {
        PixelPanel {
            VStack(alignment: .leading, spacing: 8) {
                PixelSectionTitle(title: "Week 12 report")
                Text("Cash is up $2,140 on last week.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.pixelInk)
            }
        }
    }
    .padding()
    .background(Theme.screenBackground)
}

// MARK: - Buttons and tiles

/// A button in the game's own hand: a flat fill with the pixel frame and
/// the top bevel `PixelPanel` uses, and a one-pixel drop when pressed — the
/// same press the speed control has. Used for the choices on a decision
/// sheet, where `.borderedProminent` read as somebody else's app.
struct PixelButtonStyle: ButtonStyle {
    var fill: Color = Theme.pixelAccent
    var ink: Color = Theme.pixelInk

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Theme.ink(on: fill))
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(fill.opacity(configuration.isPressed ? 0.88 : 1))
            .overlay {
                PixelPanelBorder(thickness: 2, corner: 2)
                    .fill(ink.opacity(0.55))
            }
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(0.18))
                    .frame(height: 2)
                    .padding(.horizontal, 2)
                    .padding(.top, 2)
            }
            .compositingGroup()
            .offset(y: configuration.isPressed ? 1 : 0)
            .animation(Theme.Motion.selection, value: configuration.isPressed)
    }
}

/// An SF Symbol on a small pixel-framed square of paper, for a sheet whose
/// subject has no face to draw.
struct PixelIconTile: View {
    let systemImage: String
    var tint: Color = Theme.pixelAccent
    var size: CGFloat = 64

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.44, weight: .bold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(Theme.pixelPaper)
            .overlay {
                PixelPanelBorder(thickness: 3, corner: 3)
                    .fill(Theme.pixelInk)
            }
            .accessibilityHidden(true)
    }
}
