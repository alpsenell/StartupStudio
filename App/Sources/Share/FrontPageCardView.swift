import SwiftUI
import UIKit

/// The week's front page as a card: the existing `NewspaperPage` for one
/// issue, set above the fold, on a mat with the company's name and the
/// game's along the bottom.
///
/// Two passes: the page is laid out at a phone-ish width and lets itself
/// be as tall as it needs, then that picture is fitted into the card. A
/// page is a scroll of text and the card is a fixed 540×675, so the fit
/// is the honest way to frame it — nothing is re-flowed, nothing is cut.
struct FrontPageCardView: View {
    let page: UIImage
    let issue: NewspaperIssue
    let companyName: String

    /// The width the page is laid out at before it is fitted: wide enough
    /// that its columns read, narrow enough that the fit stays near 1:1.
    static let pageWidth: CGFloat = 480

    @MainActor
    static func render(issue: NewspaperIssue, companyName: String) -> UIImage? {
        guard let page = ShareRenderer.render(
            NewspaperPage(issue: issue, aboveTheFold: true),
            width: pageWidth
        ) else { return nil }
        return ShareRenderer.render(FrontPageCardView(page: page, issue: issue, companyName: companyName))
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: Theme.Spacing.md) {
                Image(uiImage: page)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(page.size.width / page.size.height, contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay {
                        PixelPanelBorder(thickness: 3, corner: 3)
                            .fill(ShareInk.ink)
                    }
                    .shadow(color: ShareInk.ink.opacity(0.25), radius: 0, x: 4, y: 4)
                HStack {
                    // MARK: Iteration 18 — the studio mark beside the name
                    // on the mat. The page above carries it in its own
                    // masthead; nothing is drawn without one.
                    if let markSeed = issue.markSeed {
                        StudioMarkView(seed: markSeed, size: 16)
                    }
                    // MARK: end of Iteration 18
                    Text(companyName)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(ShareInk.ink)
                        .lineLimit(1)
                    Spacer(minLength: Theme.Spacing.md)
                    Text(issue.dateline)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(ShareInk.faint)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            ShareFooter(line: issue.isInProgress ? "Week \(issue.week) so far" : "Week \(issue.week)")
        }
        .background(ShareInk.paperShade)
        .overlay {
            PixelPanelBorder(thickness: 6, corner: 6)
                .fill(ShareInk.ink)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Front page card: \(issue.masthead), week \(issue.week). \(issue.lead.headline)")
    }
}
