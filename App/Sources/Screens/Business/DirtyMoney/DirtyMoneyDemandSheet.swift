import SwiftUI
import TycoonEngine

/// Iteration 11, wave two — W1. One string, on pixel paper, with a clock
/// and three answers.
///
/// Comply, stall, refuse. Each row carries what it costs and what it does
/// to the heat before it is pressed, and a row that cannot be taken says
/// why in place of the cost. Doing nothing is also an answer: the sheet
/// says which one, and how long it has.
struct DirtyMoneyDemandSheet: View {
    let engine: GameEngine
    let demand: DirtyMoneyDemand
    let backer: DirtyMoneyBacker

    @Environment(\.dismiss) private var dismiss
    @State private var confirming: DirtyMoneyAnswer?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    PixelPanel {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            PixelText(
                                text: demand.kind.title, scale: 2, color: Theme.pixelAccent
                            )
                            Text(demand.kind.body)
                                .font(.footnote)
                                .foregroundStyle(Theme.pixelInk)
                                .fixedSize(horizontal: false, vertical: true)
                            Divider().background(Theme.pixelInk.opacity(0.3))
                            HStack(alignment: .firstTextBaseline) {
                                Text(backer.displayName)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.pixelInk.opacity(0.7))
                                Spacer(minLength: Theme.Spacing.sm)
                                Text(clock)
                                    .font(.caption.weight(.semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(Theme.warning)
                            }
                        }
                    }

                    CardView("What you can say", systemImage: "bubble.left.and.bubble.right.fill") {
                        VStack(spacing: Theme.Spacing.sm) {
                            ForEach(DirtyMoneyAnswer.allCases, id: \.rawValue) { answer in
                                DirtyMoneyAnswerRow(
                                    answer: answer,
                                    detail: detail(answer),
                                    refusal: refusal(answer)
                                ) {
                                    confirming = answer
                                }
                            }
                        }
                    }

                    CardView("Where you stand", systemImage: "thermometer.medium") {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            DirtyMoneyThermometer(heat: engine.state.dirtyMoney.heat)
                            Text(nothingLine)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.screenBackground)
            .navigationTitle("They want something")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Not now") { dismiss() }
                }
            }
        }
        .confirmationDialog(
            confirming.map(confirmTitle) ?? "",
            isPresented: dialogPresented,
            titleVisibility: .visible,
            presenting: confirming
        ) { answer in
            Button(answer.displayName, role: answer == .refuse ? .destructive : nil) {
                Haptics.tap()
                engine.send(.answerDirtyMoneyDemand(answer))
                dismiss()
            }
            Button("Wait", role: .cancel) {}
        } message: { answer in
            Text(confirmBody(answer))
        }
    }

    // MARK: - Copy

    private var clock: String {
        let left = demand.daysLeft(from: engine.state.day)
        return left == 0 ? "They want an answer today" : "\(left) days to answer"
    }

    private var nothingLine: String {
        "Say nothing and the deadline refuses for you, which they read as a refusal with worse manners."
    }

    private func refusal(_ answer: DirtyMoneyAnswer) -> String? {
        engine.state.dirtyMoneyAnswerRefusal(answer, balance: engine.balance)?.sentence
    }

    /// What it costs, on the button, before it is pressed.
    private func detail(_ answer: DirtyMoneyAnswer) -> String {
        let config = engine.balance.dirtyMoney
        switch answer {
        case .comply:
            let heat = Int(config.complyHeatRelief.rounded())
            if demand.amount > 0 {
                return "\(demand.amount.money) · heat −\(heat) · it goes on your record as laundering"
            }
            return "\(demand.kind.complyLabel) · heat −\(heat)"
        case .stall:
            let heat = Int(DirtyMoney.heatDelta(.stall, kind: demand.kind, balance: config).rounded())
            return demand.stalled
                ? "You have already asked once"
                : "\(config.stallDays) more days · heat +\(heat)"
        case .refuse:
            let heat = Int(DirtyMoney.heatDelta(.refuse, kind: demand.kind, balance: config).rounded())
            return "Free today · heat +\(heat)"
        }
    }

    private func confirmTitle(_ answer: DirtyMoneyAnswer) -> String {
        switch answer {
        case .comply: "\(demand.kind.complyLabel)?"
        case .stall: "Ask them to wait?"
        case .refuse: "Tell them no?"
        }
    }

    private func confirmBody(_ answer: DirtyMoneyAnswer) -> String {
        switch answer {
        case .comply:
            demand.amount > 0
                ? "The money goes out today and onto your own record with it."
                : "It is done, and it stays done for as long as the money is theirs."
        case .stall:
            "Once. They will be pleasant about it and they will remember it."
        case .refuse:
            "They do not argue. Things happen instead, and not to you first."
        }
    }

    private var dialogPresented: Binding<Bool> {
        Binding(
            get: { confirming != nil },
            set: { presented in if !presented { confirming = nil } }
        )
    }
}

/// One answer, with what it costs — or, when it cannot be given, why not.
struct DirtyMoneyAnswerRow: View {
    let answer: DirtyMoneyAnswer
    let detail: String
    let refusal: String?
    let tap: () -> Void

    var body: some View {
        Button(action: tap) {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                Image(systemName: answer.symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(answer.displayName)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(refusal == nil ? .primary : .secondary)
                    Text(refusal ?? detail)
                        .font(.caption)
                        .foregroundStyle(refusal == nil ? Color.secondary : Theme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Theme.Spacing.sm)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressableRow)
        .disabled(refusal != nil)
        .accessibilityLabel("\(answer.displayName). \(refusal ?? detail)")
    }

    private var tint: Color {
        guard refusal == nil else { return .secondary }
        switch answer {
        case .comply: return Theme.accent
        case .stall: return Theme.warning
        case .refuse: return Theme.negativeCash
        }
    }
}
