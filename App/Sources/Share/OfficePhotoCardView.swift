import PixelKit
import SwiftUI
import TycoonEngine

/// The office as a photograph: the same frame the front page prints,
/// framed at 540×675 with the company's name as the masthead and the
/// game date under it.
///
/// The picture is the newspaper composer's own — the office as it stood
/// this week, at a fixed scene moment — so the photo on the card is the
/// photo in the paper, and the same day shares the same picture.
struct OfficePhotoCardView: View {
    let engine: GameEngine

    private var state: GameState { engine.state }

    private var photo: NewspaperIssue.Photo? {
        NewspaperComposer(state: state, content: engine.content, balance: engine.balance)
            .issues().last?.photo
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: Theme.Spacing.lg) {
                masthead
                if let photo {
                    OfficePhotoView(scene: photo.scene, moment: photo.moment)
                        .frame(maxWidth: .infinity)
                        .background(ShareInk.ink.opacity(0.06))
                        .overlay {
                            PixelPanelBorder(thickness: 4, corner: 4)
                                .fill(ShareInk.ink)
                        }
                        .shadow(color: ShareInk.ink.opacity(0.25), radius: 0, x: 4, y: 4)
                    Text(photo.caption)
                        .font(.system(size: 14, weight: .regular, design: .serif).italic())
                        .foregroundStyle(ShareInk.ink.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                dateLine
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            ShareFooter(line: "Day \(state.day)")
        }
        .background(ShareInk.paper)
        .overlay {
            PixelPanelBorder(thickness: 6, corner: 6)
                .fill(ShareInk.ink)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Office photo card: \(state.company.name), \(state.company.officeTier.displayName), "
                + "\(state.calendar.longLabel), \(state.headcount) on payroll"
        )
    }

    /// The company's name in the game's hand, over a double rule, the way
    /// the paper's masthead sits.
    private var masthead: some View {
        VStack(spacing: Theme.Spacing.sm) {
            PixelText(text: "The office", scale: 2, color: ShareInk.accent)
            PixelCompanyName(name: state.company.name, scale: 4, color: ShareInk.ink)
            VStack(spacing: 2) {
                ShareRule(height: 3)
                ShareRule(height: 1)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var dateLine: some View {
        VStack(spacing: 6) {
            PixelText(text: state.calendar.longLabel, scale: 3, color: ShareInk.ink)
            Text(
                "\(state.company.officeTier.displayName) · \(state.city.district.displayName) · "
                    + "\(state.headcount) on payroll · \(state.calendar.season.displayName)"
            )
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(ShareInk.faint)
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}
