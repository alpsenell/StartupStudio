import SwiftUI
import TycoonContent
import TycoonEngine

// MARK: J5 (announce)

/// Iteration 12 — J5. "Announce for <day>", on pixel paper.
///
/// The press release first — the build, today's ETA and what saying a date
/// out loud buys and costs — then one button per date, each carrying its
/// own slack and risk, and a way to stay quiet. Every number on the sheet
/// is the balance's, not restated here.
struct AnnounceSheet: View {
    let engine: GameEngine
    let productID: UUID

    @Environment(\.dismiss) private var dismiss
    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// See `GameShell.shared`: read optionally, because SwiftUI updates
    /// presented content before the environment is installed.
    private var shell: GameShell { injectedShell ?? .shared }

    /// Slack over today's ETA the sheet offers, in days, up to the
    /// balance's `announce.maxSlackDays` (14): the "how it fails" check
    /// found a date four weeks past the ETA never missed.
    static let slackOptions = [0, 7, 14]
    /// The one it proposes first.
    static let defaultSlack = 14

    private var state: GameState { engine.state }
    private var product: Product? { state.product(id: productID) }
    private var eta: ShipETA? {
        product.flatMap { state.shipETA(for: $0, balance: engine.balance, content: engine.content) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    if let product {
                        release(product)
                        choices(product)
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.screenBackground)
            .navigationTitle("Announce the date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not yet") { dismiss() }
                }
            }
        }
    }

    // MARK: - The press release

    private func release(_ product: Product) -> some View {
        PixelPanel(contentPadding: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                PixelSectionTitle(title: "For immediate release")
                PixelText(text: product.name, scale: 3, color: Theme.pixelInk, shadow: true)
                if let eta {
                    Text(etaLine(eta))
                        .font(.callout)
                        .foregroundStyle(Theme.pixelInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Divider().overlay(Theme.pixelInk.opacity(0.3))
                ForEach(tradeLines, id: \.text) { line in
                    HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                        Image(systemName: line.icon)
                            .font(.caption)
                            .foregroundStyle(line.tint)
                            .frame(width: 18)
                            .accessibilityHidden(true)
                        Text(line.text)
                            .font(.footnote)
                            .foregroundStyle(Theme.pixelInk.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func etaLine(_ eta: ShipETA) -> String {
        eta.isReady
            ? "It could ship today. A date is a promise to wait, or to polish."
            : "At today's pace it clears the ship gate on \(label(eta.day)), \(eta.daysAway) day\(eta.daysAway == 1 ? "" : "s") from now. Skills grow and people leave; the ETA assumes neither."
    }

    private struct TradeLine {
        let icon: String
        let text: String
        let tint: Color
    }

    private var tradeLines: [TradeLine] {
        let config = engine.balance.announce
        let kept = Announce.hypeKept(days: 30, balance: engine.balance)
        let first = Announce.slipCost(slipNumber: 1, balance: engine.balance)
        let second = Announce.slipCost(slipNumber: Announce.voidAfterSlips, balance: engine.balance)
        return [
            TradeLine(
                icon: "flame.fill",
                text: "Hype holds: −\(pct(config.hypeDecayRate))% a day, not −\(pct(engine.balance.hypeDecayRate))%. Over 30 days you keep \(pct(kept.announced))% of it, not \(pct(kept.quiet))%.",
                tint: Theme.pixelAccent
            ),
            TradeLine(
                icon: "megaphone.fill",
                text: "Every campaign lands ×\(factor(config.campaignFactor)) until it ships. The paper prints the date; the war room counts down to it.",
                tint: Theme.pixelAccent
            ),
            TradeLine(
                icon: "calendar.badge.exclamationmark",
                text: "Miss it: reputation −\(Int(first.reputation)), hype ×\(factor(first.hypeFactor)), a correction in print. Miss the new date: −\(Int(second.reputation)), ×\(factor(second.hypeFactor)), and nobody prints a third.",
                tint: Theme.warning
            ),
            TradeLine(
                icon: "doc.on.doc.fill",
                text: "Rivals read it too: the copycat is ready \(config.copycatDelayWeeks) weeks after launch, not \(RivalDepthTuning.copycatDelayWeeks).",
                tint: Theme.warning
            ),
        ]
    }

    // MARK: - The choices

    @ViewBuilder
    private func choices(_ product: Product) -> some View {
        let refusal = state.announceRefusal(
            productID: productID,
            day: state.announceEarliestDay(balance: engine.balance),
            balance: engine.balance,
            content: engine.content
        )
        if let refusal, refusal != .tooSoon, refusal != .tooFar {
            Text(refusal.sentence)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(options, id: \.day) { option in
                    Button { announce(option.day, product: product) } label: {
                        row(
                            title: "Announce for \(label(option.day))",
                            detail: detail(for: option),
                            emphasised: option.isDefault,
                            // MARK: K7 (partner and diary)
                            diary: option.clash.map { diaryLine($0, for: option.day) }
                            // MARK: end K7
                        )
                    }
                    .buttonStyle(.pressableRow)
                    .accessibilityLabel("Announce \(product.name) for \(label(option.day))")
                    .accessibilityHint(detail(for: option))
                }
                Button { dismiss() } label: {
                    row(
                        title: "Stay quiet",
                        detail: "No deadline and no early copycat. Hype fades \(pct(engine.balance.hypeDecayRate))% a day, as it does.",
                        emphasised: false
                    )
                }
                .buttonStyle(.pressableRow)
            }
        }
    }

    private struct Option {
        let day: Int
        let slack: Int
        let isDefault: Bool
        // MARK: K7 (partner and diary)
        /// A date in the family diary near this one, if any.
        var clash: FamilyDate? = nil
        // MARK: end K7
    }

    // MARK: K7 (partner and diary)

    /// "Nora's birthday is two days before", from the diary.
    private func diaryLine(_ clash: FamilyDate, for day: Int) -> String {
        let offset = clash.day - day
        let when: String = switch offset {
        case 0: "is on the day"
        case 1: "is the day after"
        case -1: "is the day before"
        case let days where days > 0: "is \(days) days after"
        case let days: "is \(-days) days before"
        }
        return "\(clash.label) \(when)"
    }

    // MARK: end K7

    /// One option per distinct date: slack that the three-week minimum
    /// swallows collapses into the earliest date it allows.
    private var options: [Option] {
        guard let eta else { return [] }
        var seen: Set<Int> = []
        var result: [Option] = []
        for slack in Self.slackOptions {
            guard let day = state.announceProposal(
                productID: productID, slackDays: slack, balance: engine.balance, content: engine.content
            ), seen.insert(day).inserted,
                  // A date within three days of the one before is not a
                  // different choice.
                  result.last.map({ day - $0.day >= 4 }) ?? true
            else { continue }
            result.append(Option(
                day: day, slack: day - eta.day, isDefault: slack == Self.defaultSlack,
                // MARK: K7 (partner and diary)
                clash: state.announceDiaryClash(day: day, balance: engine.balance, content: engine.content)
                // MARK: end K7
            ))
        }
        return result
    }

    private func detail(for option: Option) -> String {
        let out = option.day - state.day
        let slack: String = switch option.slack {
        case ..<1: "On the ETA itself: any slow week slips it"
        case ..<7: "\(option.slack) days of slack: a bad week slips it"
        case ..<14: "\(option.slack) days of slack: room for one bad week"
        default: "\(option.slack) days of slack: room for a bad fortnight"
        }
        return "\(slack) · \(out) days out" + (option.isDefault ? " · the usual" : "")
    }

    private func row(title: String, detail: String, emphasised: Bool, diary: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(emphasised ? Theme.accent : .primary)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            // MARK: K7 (partner and diary)
            if let diary {
                Label(diary, systemImage: "calendar.badge.exclamationmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.romance)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // MARK: end K7
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func announce(_ day: Int, product: Product) {
        let refusal = state.announceRefusal(
            productID: productID, day: day, balance: engine.balance, content: engine.content
        )
        shell.toasts.send(
            .announceShipDate(productID: productID, day: day),
            to: engine,
            ack: "\(product.name) ships \(label(day)). It is in print",
            rejected: refusal?.sentence ?? "The press would not take that date.",
            icon: "megaphone.fill"
        )
        Haptics.commit()
        dismiss()
    }

    // MARK: - Formatting

    private func label(_ day: Int) -> String {
        AnnounceEventPresenter.dateLabel(day, today: state.day)
    }

    private func pct(_ value: Double) -> Int { Int((value * 100).rounded()) }

    private func factor(_ value: Double) -> String {
        value == value.rounded() ? "\(Int(value))" : String(format: "%g", value)
    }
}

// MARK: end J5
