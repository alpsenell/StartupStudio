import SwiftUI

/// A single-selection bar of icon + label pills that scrolls horizontally
/// when the labels do not fit.
///
/// `.pickerStyle(.segmented)` divides the width evenly and then truncates,
/// which is fine for three segments and unreadable at six ("Contr…",
/// "Market…", "Investo…" on an iPhone at the default text size — worse at
/// larger ones). A pill bar keeps every label whole at any Dynamic Type
/// size and scrolls instead, and the icons make a section recognisable
/// before the word is read.
///
/// The visual language is the journal's filter chips, which is where this
/// app already says "pick one of these".
struct SegmentPillBar<Segment: Hashable & Identifiable>: View {
    /// The segments, in bar order.
    let segments: [Segment]
    /// The label shown on a segment's pill.
    let title: (Segment) -> String
    /// The SF Symbol shown before the label.
    let systemImage: (Segment) -> String
    /// What the whole bar is choosing between, for VoiceOver.
    let accessibilityLabel: String
    @Binding var selection: Segment

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(segments) { segment in
                        pill(segment)
                            .id(segment.id)
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.sm)
            }
            .scrollClipDisabled(false)
            .accessibilityLabel(accessibilityLabel)
            // A deep link can land on a segment that is off-screen; bring it
            // into view rather than leaving the bar looking unchanged.
            .onChange(of: selection, initial: true) { _, new in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(new.id, anchor: .center)
                }
            }
        }
    }

    private func pill(_ segment: Segment) -> some View {
        let isOn = segment == selection
        return Button {
            guard !isOn else { return }
            Haptics.tap()
            withAnimation(.spring(duration: 0.25)) { selection = segment }
        } label: {
            Label(title(segment), systemImage: systemImage(segment))
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm - 1)
                .background(isOn ? Theme.accent : Theme.chipBackground, in: Capsule())
                .foregroundStyle(isOn ? Color.white : Color.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title(segment))
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}
