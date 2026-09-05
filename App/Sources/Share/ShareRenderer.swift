import CoreGraphics
import SwiftUI
import TycoonEngine
import UIKit

// MARK: Iteration 7 — share cards (R4)

/// The three cards (biography, front page, office photo) are laid out at
/// `cardSize` points and rendered at `scale` for a 1080×1350 image.
///
/// A card is a fixed-size, non-scrolling view; `render` lays it out at
/// exactly `cardSize` and rasterises it. The cards use their own fixed
/// inks (`ShareInk`) rather than the theme's dynamic ones so a card
/// shared from a dark phone is the same picture as one shared from a
/// light phone.
enum ShareRenderer {
    static let cardSize = CGSize(width: 540, height: 675)
    static let scale: CGFloat = 2

    /// Rasterises a card at `cardSize` × `scale`.
    @MainActor
    static func render(_ card: some View, colorScheme: ColorScheme = .light) -> UIImage? {
        let renderer = ImageRenderer(
            content: card
                .frame(width: cardSize.width, height: cardSize.height)
                .environment(\.colorScheme, colorScheme)
        )
        renderer.scale = scale
        renderer.proposedSize = ProposedViewSize(cardSize)
        return renderer.uiImage
    }

    /// Rasterises an arbitrary view at a width, letting it take the height
    /// it needs — the front page's first pass.
    @MainActor
    static func render(_ view: some View, width: CGFloat, colorScheme: ColorScheme = .light) -> UIImage? {
        let renderer = ImageRenderer(
            content: view
                .frame(width: width)
                .environment(\.colorScheme, colorScheme)
        )
        renderer.scale = scale
        renderer.proposedSize = ProposedViewSize(width: width, height: nil)
        return renderer.uiImage
    }

    /// The image for one card, ready for `ShareLink`.
    @MainActor
    static func image(for card: ShareCard) -> UIImage? {
        switch card {
        case .biography(let engine, let info):
            render(BiographyCardView(engine: engine, info: info))
        case .frontPage(let issue, let companyName):
            FrontPageCardView.render(issue: issue, companyName: companyName)
        case .officePhoto(let engine):
            render(OfficePhotoCardView(engine: engine))
        }
    }
}

/// The card a share button asked for. Rendered once by `ShareCardSheet`.
@MainActor
enum ShareCard {
    case biography(engine: GameEngine, info: GameOverInfo)
    case frontPage(issue: NewspaperIssue, companyName: String)
    case officePhoto(engine: GameEngine)

    /// The share sheet's title and the preview's caption.
    var title: String {
        switch self {
        case .biography(let engine, let info):
            "\(engine.state.progression.founder.displayName) · \(info.kind.headline)"
        case .frontPage(let issue, _):
            "\(issue.masthead) · Week \(issue.week)"
        case .officePhoto(let engine):
            "\(engine.state.company.name) · \(engine.state.calendar.longLabel)"
        }
    }

    /// The file name the share sheet suggests.
    var fileName: String {
        switch self {
        case .biography: "founder-biography"
        case .frontPage(let issue, _): "front-page-week-\(issue.week)"
        case .officePhoto: "office-photo"
        }
    }
}

/// The fixed inks every card is drawn in: paper, ink and the founder's
/// indigo, the newspaper's own values, the same in both appearances.
enum ShareInk {
    static let paper = Color(red: 244 / 255, green: 238 / 255, blue: 226 / 255)
    static let paperShade = Color(red: 232 / 255, green: 225 / 255, blue: 210 / 255)
    static let ink = Color(red: 32 / 255, green: 30 / 255, blue: 42 / 255)
    static let accent = Color(red: 78 / 255, green: 74 / 255, blue: 168 / 255)
    static let success = Color(red: 52 / 255, green: 140 / 255, blue: 84 / 255)
    static let failure = Color(red: 178 / 255, green: 58 / 255, blue: 62 / 255)
    static let faint = ink.opacity(0.55)
}

/// A hairline in ink, for the cards.
struct ShareRule: View {
    var color: Color = ShareInk.ink
    var height: CGFloat = 2

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: height)
            .accessibilityHidden(true)
    }
}

/// The strip along the bottom of every card: the game's name in its own
/// hand, and whatever the card wants to say beside it.
struct ShareFooter: View {
    var line: String?
    /// A seed code, on its own line at a size a thumb can read.
    var code: SeedCode?

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.md) {
                PixelText(text: "Startup Studio", scale: 2, color: ShareInk.paper)
                Spacer(minLength: 0)
                if let line {
                    PixelText(text: line, scale: 2, color: ShareInk.paper)
                }
            }
            if let code {
                PixelText(text: code.encoded, scale: 3, color: ShareInk.paper)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .frame(maxWidth: .infinity)
        .background(ShareInk.ink)
    }
}

// MARK: - The sheet

/// What every share button opens: the card, rendered once, at a size the
/// phone can show, with the one button that hands it to the system.
///
/// A sheet rather than a bare `ShareLink` so the player sees the card
/// before it goes anywhere — and so the biography's `onShare` closure,
/// the newspaper's toolbar and the office card's camera all open the
/// same thing.
struct ShareCardSheet: View {
    let card: ShareCard

    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.lg) {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(ShareRenderer.cardSize.width / ShareRenderer.cardSize.height, contentMode: .fit)
                        .overlay {
                            PixelPanelBorder(thickness: 3, corner: 3)
                                .fill(Theme.pixelInk)
                        }
                        .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
                        .accessibilityLabel("The card: \(card.title)")
                } else {
                    Rectangle()
                        .fill(Theme.chipBackground)
                        .aspectRatio(ShareRenderer.cardSize.width / ShareRenderer.cardSize.height, contentMode: .fit)
                        .overlay { ProgressView() }
                        .accessibilityLabel("Drawing the card")
                }

                if let image {
                    ShareLink(
                        item: Image(uiImage: image),
                        preview: SharePreview(card.title, image: Image(uiImage: image))
                    ) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.system(.headline, design: .rounded))
                    }
                    .buttonStyle(PixelButtonStyle())
                    .simultaneousGesture(TapGesture().onEnded {
                        Haptics.tap()
                        Sounds.play(.tap)
                    })
                    .accessibilityHint("Opens the system share sheet with the card as a 1080 by 1350 image")
                }

                Text("A 1080 × 1350 image, the size a story wants.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Theme.screenBackground)
            .navigationTitle(card.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                // Rendered off the first frame so the sheet is up before
                // the card is drawn; the cards are a few hundred
                // milliseconds of pixel work.
                await Task.yield()
                image = ShareRenderer.image(for: card)
            }
        }
    }
}
