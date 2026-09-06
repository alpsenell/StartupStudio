import PixelKit
import SwiftUI
import TycoonEngine

// Iteration 9 — L5. Everything the side-project surfaces need to draw a
// track: an icon, the pixel vignette the catalog named, and the two lines
// that turn a `ChapterDef` into a promise the player can read.

extension SideProjectTrack {
    var systemImage: String {
        switch self {
        case .novel: "book.closed.fill"
        case .band: "guitars.fill"
        case .marathon: "figure.run"
        case .weekendApp: "hammer.fill"
        case .restaurant: "fork.knife"
        }
    }
}

/// The pixel vignette for a track, from the scene name in the catalog.
/// The engine names a scene; PixelKit draws it; nothing new was added to
/// the sprite library for this lane.
func sideProjectScene(
    _ def: BalanceConfig.SideProjectBalance.TrackDef
) -> ActivitySceneStyle {
    ActivitySceneStyle(rawValue: def.scene) ?? .hobby
}

extension BalanceConfig.SideProjectBalance.TrackDef {
    /// "Conversation and Leadership" — what the track actually runs on.
    var driverSummary: String {
        let names = drivers.compactMap(SideProjectDriver.init(rawValue:)).map(\.displayName)
        guard names.count > 1 else { return names.first ?? "Nothing in particular" }
        return names.dropLast().joined(separator: ", ") + " and " + (names.last ?? "")
    }

    /// "20 evenings, $40 a night" — the whole cost of the track, up front,
    /// before anybody commits an evening to it.
    var costSummary: String {
        let evenings = Int(chapters.reduce(0) { $0 + $1.sessions }.rounded())
        let nights = "\(evenings) evening\(evenings == 1 ? "" : "s")"
        return sessionCost > 0 ? "\(nights) · \(sessionCost.money) a night" : "\(nights) · free"
    }
}

extension BalanceConfig.SideProjectBalance.ChapterDef {
    /// What finishing this chapter pays, as a short list of chips. Empty
    /// when a chapter is its own reward, which two of them are.
    var payoutChips: [String] {
        var chips: [String] = []
        if wallet != 0 || walletUpside != 0 {
            if upsideChance > 0 {
                chips.append("\(walletUpside.money) or \(wallet.money)")
            } else {
                chips.append(wallet.money)
            }
        }
        if reputation != 0 {
            chips.append("+\(Int(reputation)) reputation")
        }
        if let perk, let known = ProgressionPerk(rawValue: perk) {
            chips.append(known.displayName)
        }
        if mood != 0 { chips.append("+\(Int(mood)) mood") }
        if health != 0 { chips.append("+\(Int(health)) health") }
        if relationships != 0 { chips.append("+\(Int(relationships)) relationships") }
        return chips
    }
}

/// A small pill, the same shape the rest of the Life tab uses for a
/// consequence you have not paid for yet.
struct SideProjectChip: View {
    let text: String
    var tint: Color = .secondary

    var body: some View {
        Text(text)
            .font(Theme.Typography.number(.caption2))
            .foregroundStyle(tint)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, 3)
            .background(Theme.chipBackground, in: Capsule())
    }
}

/// The chapter strip: four blocks, filled for the ones behind you, part
/// filled for the one you are in.
struct ChapterStrip: View {
    let chapterCount: Int
    let chapter: Int
    let progress: Double

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<max(chapterCount, 1), id: \.self) { index in
                Capsule()
                    .fill(Theme.chipBackground)
                    .frame(height: 8)
                    .overlay(alignment: .leading) {
                        GeometryReader { geometry in
                            Capsule()
                                .fill(Theme.accent)
                                .frame(width: geometry.size.width * fill(index))
                        }
                    }
                    .clipShape(Capsule())
            }
        }
        .animation(Theme.Motion.valueChange, value: progress)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Chapter \(min(chapter + 1, chapterCount)) of \(chapterCount)")
    }

    private func fill(_ index: Int) -> Double {
        if index < chapter { return 1 }
        if index == chapter { return min(max(progress, 0), 1) }
        return 0
    }
}
