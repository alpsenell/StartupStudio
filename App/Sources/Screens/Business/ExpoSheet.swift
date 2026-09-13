import SwiftUI
import TycoonContent
import TycoonEngine

// MARK: T5 (expo and pre-orders)

/// Iteration 17 — T5 (G2). The year's expo, on pixel paper.
///
/// The poster first — the date and what a demo buys and costs — then the
/// builds in development with the two numbers the demo reads (quality so
/// far, open bugs), who goes, and the answers, each with its price now and
/// what it closes later. Every number is the balance's or the engine's
/// quote, not restated here.
struct ExpoSheet: View {
    let engine: GameEngine

    @Environment(\.dismiss) private var dismiss
    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// See `GameShell.shared`: read optionally, because SwiftUI updates
    /// presented content before the environment is installed.
    private var shell: GameShell { injectedShell ?? .shared }

    @State private var pickedID: UUID?
    @State private var attendee: ExpoAttendee = .founder

    private var state: GameState { engine.state }
    private var config: BalanceConfig.ExpoBalance { engine.balance.expo }
    private var builds: [Product] { state.productsInDevelopment }
    private var booking: ExpoBooking? { state.expoBooking }

    /// The build the answers are about: the one picked, else the one
    /// booked, else the best so far.
    private var picked: Product? {
        let id = pickedID ?? booking?.productID ?? bestID
        return builds.first { $0.id == id } ?? builds.first
    }

    private var bestID: UUID? {
        builds.max { quality($0) < quality($1) }?.id
    }

    private func quality(_ product: Product) -> Double {
        state.shipForecast(productID: product.id, balance: engine.balance, content: engine.content)?.quality ?? 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    poster
                    if state.expoDaysLeft(balance: engine.balance) == nil {
                        Text(state.expoDoneThisYear() ? ExpoRefusal.alreadyDone.sentence : ExpoRefusal.notYet.sentence)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if builds.isEmpty {
                        Text("Nothing in development to show. A demo needs a build.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else {
                        buildPicker
                        attendeePicker
                        answers
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.screenBackground)
            .navigationTitle("The expo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }
                }
            }
        }
        .onAppear {
            if pickedID == nil { pickedID = booking?.productID ?? bestID }
            if let booking { attendee = booking.attendee }
        }
    }

    // MARK: - The poster

    private var poster: some View {
        PixelPanel(contentPadding: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                PixelSectionTitle(title: "On the show floor")
                PixelText(text: ExpoCopy.showName, scale: 3, color: Theme.pixelInk, shadow: true)
                Text(dateLine)
                    .font(.callout)
                    .foregroundStyle(Theme.pixelInk)
                    .fixedSize(horizontal: false, vertical: true)
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

    private var dateLine: String {
        let show = state.expoDay(balance: engine.balance)
        let label = AnnounceEventPresenter.dateLabel(show, today: state.day)
        let left = show - state.day
        return switch left {
        case ..<0: "\(label). It was this year's; the next one is in June."
        case 0: "\(label): today. One build, one demo."
        default: "\(label), \(left) day\(left == 1 ? "" : "s") from now. One build, one demo, shown with whatever it is by then."
        }
    }

    private struct TradeLine {
        let icon: String
        let text: String
        let tint: Color
    }

    private var tradeLines: [TradeLine] {
        [
            TradeLine(
                icon: "flame.fill",
                text: "A booth: +\(ExpoCopy.number(config.hype)) hype × your marketers' flair, and reputation +\(ExpoCopy.number(config.reputationGood)) if the build is \(ExpoCopy.number(config.goodQuality)) or better so far. The hallway: half of both.",
                tint: Theme.pixelAccent
            ),
            TradeLine(
                icon: "ladybug.fill",
                text: "Over \(config.crashBugs) open bugs the demo crashes: half the hype, reputation −\(ExpoCopy.number(config.reputationCrash)), and the paper was there.",
                tint: Theme.warning
            ),
            TradeLine(
                icon: "doc.on.doc.fill",
                text: "It is public from then: the copycat is ready \(config.copycatDelayWeeks) weeks after launch, not \(RivalDepthTuning.copycatDelayWeeks), and reviewers expect +\(ExpoCopy.number(config.expectationBump)).",
                tint: Theme.warning
            ),
            TradeLine(
                icon: "person.fill",
                text: "You go: an evening that week and \(ExpoCopy.number(config.founderEnergy)) energy. A marketer goes: no evening, ×\(ExpoCopy.number(config.marketerFactor)) the pitch. Nobody at the stand, and it works as the hallway.",
                tint: Theme.pixelAccent
            ),
        ]
    }

    // MARK: - The build

    private var buildPicker: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            ExpoSectionLabel(text: "Which build")
            ForEach(builds) { product in
                Button {
                    pickedID = product.id
                    Haptics.tap()
                } label: {
                    buildRow(product, selected: product.id == picked?.id)
                }
                .buttonStyle(.pressableRow)
                .accessibilityAddTraits(product.id == picked?.id ? .isSelected : [])
            }
        }
    }

    private func buildRow(_ product: Product, selected: Bool) -> some View {
        let bugs: Int = if case .development(let dev) = product.stage { dev.openBugs } else { 0 }
        let score = Int(quality(product).rounded())
        return VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(product.name)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(selected ? Theme.accent : .primary)
                Spacer(minLength: Theme.Spacing.sm)
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.accent)
                        .accessibilityHidden(true)
                }
            }
            Text("Quality \(score) so far · \(bugs) open bug\(bugs == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
            if bugs > config.crashBugs {
                Label(
                    "Over \(config.crashBugs): the demo crashes. Squash \(bugs - config.crashBugs) by the day, or show another.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.warning)
                .fixedSize(horizontal: false, vertical: true)
            } else if Double(score) >= config.goodQuality {
                Text("Good enough for the press's nod: reputation +\(ExpoCopy.number(config.reputationGood)).")
                    .font(.caption)
                    .foregroundStyle(Theme.positiveCash)
            } else {
                Text("Under \(ExpoCopy.number(config.goodQuality)): hype, and no nod from the press.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(selected ? Theme.accent : .clear, lineWidth: 2)
        )
    }

    // MARK: - Who goes

    private var attendeePicker: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            ExpoSectionLabel(text: "Who goes")
            HStack(spacing: Theme.Spacing.sm) {
                attendeeButton(.founder, title: "You", detail: founderDetail, enabled: true)
                attendeeButton(
                    .marketer, title: "A marketer",
                    detail: state.expoHasMarketer
                        ? "No evening · ×\(ExpoCopy.number(config.marketerFactor)) the pitch"
                        : ExpoRefusal.noMarketer.sentence,
                    enabled: state.expoHasMarketer
                )
            }
        }
    }

    private var founderDetail: String {
        let evening = "An evening that week, energy −\(ExpoCopy.number(config.founderEnergy))"
        guard let left = state.eveningsLeftThisWeek(engine.balance), state.expoDay(balance: engine.balance) == state.day
        else { return evening }
        return left > 0 ? "\(evening) · \(left) left tonight" : "No evening left today: the stand would stand empty"
    }

    private func attendeeButton(_ who: ExpoAttendee, title: String, detail: String, enabled: Bool) -> some View {
        let selected = attendee == who
        return Button {
            attendee = who
            Haptics.tap()
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(selected ? Theme.accent : .primary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(selected ? Theme.accent : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.pressableRow)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.55)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: - The answers

    @ViewBuilder
    private var answers: some View {
        if let product = picked {
            VStack(spacing: Theme.Spacing.sm) {
                ExpoSectionLabel(text: "The answer")
                if let booking {
                    let changed = booking.productID != product.id || booking.attendee != attendee
                    let stand = booking.booth == .booth ? "a booth" : "the hallway"
                    answerRow(
                        title: changed
                            ? "Show \(product.name) instead · free"
                            : "\(product.name) is booked · \(stand), \(booking.paid.money) paid",
                        detail: quoteLine(product, booth: booking.booth),
                        emphasised: changed,
                        refusal: changed ? refusal(product, booking.booth) : nil,
                        enabled: changed
                    ) { book(product, booth: booking.booth) }
                } else {
                    let boothPrice = state.expoPrice(.booth, balance: engine.balance)
                    answerRow(
                        title: boothPrice.map { "Take a booth · \($0.money)" } ?? "Take a booth",
                        detail: quoteLine(product, booth: .booth),
                        emphasised: true,
                        refusal: refusal(product, .booth)
                    ) { book(product, booth: .booth) }
                    answerRow(
                        title: "Work the hallway · \(config.hallway.money)",
                        detail: quoteLine(product, booth: .hallway),
                        emphasised: false,
                        refusal: refusal(product, .hallway)
                    ) { book(product, booth: .hallway) }
                }
                answerRow(
                    title: "Skip it",
                    detail: booking.map { "The \($0.paid.money) is gone. No hype, no copycat head start, nothing to live up to." }
                        ?? "Keep the board dark: no hype, no copycat head start, nothing for reviewers to live up to.",
                    emphasised: false,
                    refusal: nil
                ) { skip() }
            }
        }
    }

    private func refusal(_ product: Product, _ booth: ExpoBooth) -> ExpoRefusal? {
        state.expoRefusal(productID: product.id, booth: booth, attendee: attendee, balance: engine.balance)
    }

    /// What this demo would do today, in one line: the quote, then what it
    /// closes later.
    private func quoteLine(_ product: Product, booth: ExpoBooth) -> String {
        guard let quote = state.expoQuote(
            productID: product.id, booth: booth, attendee: attendee,
            balance: engine.balance, content: engine.content
        ) else { return "" }
        var parts = ["+\(Int(quote.hype.rounded())) hype"]
        if quote.crashed {
            parts.append("reputation −\(ExpoCopy.number(-quote.reputation)): it crashes at \(quote.openBugs) bugs")
        } else if quote.reputation > 0 {
            parts.append("reputation +\(ExpoCopy.number(quote.reputation))")
        } else {
            parts.append("no nod from the press")
        }
        if !quote.staffed { parts.append("nobody at the stand: half") }
        let later = "then the copycat's clock is \(config.copycatDelayWeeks) weeks and reviewers expect +\(ExpoCopy.number(config.expectationBump))"
        return parts.joined(separator: ", ") + " · " + later
    }

    private func answerRow(
        title: String,
        detail: String,
        emphasised: Bool,
        refusal: ExpoRefusal?,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(emphasised && refusal == nil ? Theme.accent : .primary)
                Text(refusal?.sentence ?? detail)
                    .font(.caption)
                    .foregroundStyle(refusal == nil ? Color.secondary : Theme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.pressableRow)
        .disabled(refusal != nil || !enabled)
        .opacity(refusal != nil ? 0.6 : 1)
        .accessibilityHint(refusal?.sentence ?? detail)
    }

    private func book(_ product: Product, booth: ExpoBooth) {
        let refusal = refusal(product, booth)
        let today = state.expoDay(balance: engine.balance) <= state.day
        shell.toasts.send(
            .showAtExpo(productID: product.id, booth: booth, attendee: attendee),
            to: engine,
            ack: today ? "\(product.name) is on the show floor" : "\(product.name) is booked for the expo",
            rejected: refusal?.sentence ?? "The expo would not take that booking.",
            icon: "megaphone.fill"
        )
        Haptics.commit()
        dismiss()
    }

    private func skip() {
        shell.toasts.send(
            .skipExpo,
            to: engine,
            ack: "Not this year. The board stays dark",
            rejected: "The expo is not on.",
            icon: "moon.zzz.fill"
        )
        dismiss()
    }
}

/// A small caps label over a group of rows.
private struct ExpoSectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.bold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: end T5
