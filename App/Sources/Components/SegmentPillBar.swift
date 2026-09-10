import SwiftUI

/// A single-selection bar of icon + label pills.
///
/// `.pickerStyle(.segmented)` divides the width evenly and then truncates,
/// which is fine for three segments and unreadable at six ("Contr…",
/// "Market…", "Investo…" on an iPhone at the default text size — worse at
/// larger ones). The segments scroll as one row with every label whole and
/// a fade at the trailing edge that says more is there.
///
/// Iteration 13 (U1, C7): always one row. Five or more used to lay out as
/// a grid of three, which cost the Business tab two rows of chrome (213
/// px of 2,000) and still clipped "Contr…" once it carried a badge.
///
/// A segment may carry a badge: the count of things waiting in it.
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
    /// A count per segment id, shown as a small numeral on the pill.
    var badges: [Segment.ID: Int] = [:]

    // MARK: U1 (ux: the first-hour fixes)
    // C7: one scrolling row whatever the count; the three-column grid is gone.
    var body: some View {
        scroller
    }
    // MARK: end U1

    private var scroller: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(segments) { segment in
                        pill(segment, fillsWidth: false)
                            .id(segment.id)
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.sm)
            }
            .scrollClipDisabled(false)
            // The trailing fade says the row continues.
            .mask {
                HStack(spacing: 0) {
                    Color.black
                    LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: 24)
                }
            }
            .accessibilityLabel(accessibilityLabel)
            // A deep link can land on a segment that is off-screen; bring it
            // into view rather than leaving the bar looking unchanged.
            .onChange(of: selection, initial: true) { _, new in
                withAnimation(Theme.Motion.entrance) {
                    proxy.scrollTo(new.id, anchor: .center)
                }
            }
        }
    }

    private func pill(_ segment: Segment, fillsWidth: Bool) -> some View {
        let isOn = segment == selection
        let badge = badges[segment.id] ?? 0
        return Button {
            guard !isOn else { return }
            Haptics.tap()
            withAnimation(Theme.Motion.selection) { selection = segment }
        } label: {
            HStack(spacing: Theme.Spacing.xs) {
                Label(title(segment), systemImage: systemImage(segment))
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(.caption2, design: .rounded).weight(.bold).monospacedDigit())
                        .foregroundStyle(isOn ? Theme.accent : Theme.ink(on: Theme.warning))
                        .padding(.horizontal, 5)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(isOn ? Theme.ink(on: Theme.accent) : Theme.warning, in: Capsule())
                }
            }
            .fixedSize(horizontal: !fillsWidth, vertical: false)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm - 1)
            // The Business tab's primary navigation: a 34pt pill is
            // under the 44pt minimum, so the hit area is grown past
            // the drawn capsule rather than the capsule fattened.
            .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: 30)
            .background(isOn ? Theme.accent : Theme.chipBackground, in: Capsule())
            .foregroundStyle(isOn ? Theme.ink(on: Theme.accent) : Color.secondary)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(badge > 0 ? "\(title(segment)), \(badge) waiting" : title(segment))
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}
