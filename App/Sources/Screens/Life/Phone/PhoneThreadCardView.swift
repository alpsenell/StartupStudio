import SwiftUI
import TycoonEngine

// MARK: Iteration 9 — L1 (the phone)

/// A thread as a 1080×1350 card: the last eight bubbles on the share
/// cards' fixed paper, with who it is at the top and the day at the
/// bottom. The screenshot of the partner's texts during launch week is
/// the whole point of the phone, so it gets a card of its own rather than
/// leaving the player to use the system screenshot.
struct PhoneThreadCardView: View {
    let engine: GameEngine
    let counterpart: PhoneCounterpart

    /// The tail of the thread: enough for the shape of the conversation,
    /// few enough that the card does not have to shrink the type.
    private static let bubbleLimit = 8

    private var state: GameState { engine.state }
    private var thread: PhoneThread? { state.life.phone.thread(with: counterpart) }

    private var messages: [PhoneMessage] {
        // V2 (C10): the card shows the thread the phone shows.
        Array((thread?.shownMessages ?? []).suffix(Self.bubbleLimit))
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                header
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(messages) { message in
                        CardBubble(message: message)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            ShareFooter(line: "Day \(state.day)")
        }
        .background(ShareInk.paper)
        .overlay {
            PixelPanelBorder(thickness: 6, corner: 6)
                .fill(ShareInk.ink)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Phone card: \(messages.count) messages with "
                + "\(state.phoneName(for: counterpart)) on day \(state.day)"
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.md) {
                if let seed = state.phoneSeed(for: counterpart) {
                    PixelPortrait(seed: seed, size: 52)
                } else {
                    PixelIconTile(systemImage: "building.2.fill", tint: ShareInk.accent, size: 52)
                }
                VStack(alignment: .leading, spacing: 2) {
                    PixelText(
                        text: String(localized: "Messages", comment: "Bitmap title over the phone: the status bar and the share card. Uppercase A-Z only: the pixel face has no lowercase and no accents"),
                        scale: 2,
                        color: ShareInk.accent
                    )
                    Text(state.phoneName(for: counterpart))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(ShareInk.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(state.phoneRelation(for: counterpart))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(ShareInk.faint)
                }
                Spacer(minLength: 0)
            }
            VStack(spacing: 2) {
                ShareRule(height: 3)
                ShareRule(height: 1)
            }
        }
    }
}

/// A bubble in the card's fixed inks, so a card shared from a dark phone
/// is the same picture as one shared from a light one.
private struct CardBubble: View {
    let message: PhoneMessage

    private var isMarker: Bool { message.kind == .unanswered }

    var body: some View {
        HStack {
            if message.fromFounder { Spacer(minLength: 60) }
            Text(message.text)
                .font(.system(size: 15, weight: isMarker ? .regular : .medium, design: .rounded))
                .italic(isMarker)
                .foregroundStyle(ink)
                .multilineTextAlignment(message.fromFounder ? .trailing : .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(fill)
                .overlay {
                    PixelPanelBorder(thickness: 2, corner: 2)
                        .fill(ShareInk.ink.opacity(isMarker ? 0.3 : 0.75))
                }
            if !message.fromFounder { Spacer(minLength: 60) }
        }
    }

    private var fill: Color {
        if isMarker { return ShareInk.paperShade }
        return message.fromFounder ? ShareInk.accent : ShareInk.paperShade
    }

    private var ink: Color {
        if isMarker { return ShareInk.faint }
        return message.fromFounder ? ShareInk.paper : ShareInk.ink
    }
}
