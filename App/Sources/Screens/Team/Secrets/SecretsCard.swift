import SwiftUI
import TycoonContent
import TycoonEngine

/// *The office* — the thread the room is running behind the founder's
/// back, everything they have managed to learn about it, and the six
/// things they can do about it, each with its cost on the button and its
/// refusal in place of one.
///
/// Only ever on screen once something has actually started: a card that
/// said "nothing is going on" would be a card that says the game has this
/// feature, which is not the same thing. The founder's first sight of it
/// is a clue.
struct SecretsCard: View {
    let engine: GameEngine

    @State private var confirming: SecretResponse?

    var body: some View {
        Group {
            if let thread = engine.state.secrets.open, let kind = thread.secretKind {
                CardView("The office", systemImage: kind.systemImageName) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        header(kind, thread)
                        SecretClueList(thread: thread)
                        Divider()
                        responses(thread)
                    }
                }
            } else if let last = engine.state.secrets.closed.last,
                      let kind = last.secretKind,
                      engine.state.day - (last.closedDay ?? 0) <= 30 {
                CardView("The office", systemImage: kind.systemImageName) {
                    closedRow(kind, last)
                }
            }
        }
        .confirmationDialog(
            confirming.map { confirmTitle($0) } ?? "",
            isPresented: dialogPresented,
            titleVisibility: .visible,
            presenting: confirming
        ) { response in
            Button(response.displayName, role: response == .ignore ? .destructive : nil) {
                Haptics.tap()
                engine.send(.respondToSecret(response))
            }
            Button("Not yet", role: .cancel) {}
        } message: { response in
            Text(confirmBody(response))
        }
    }

    // MARK: - The thread

    @ViewBuilder
    private func header(_ kind: SecretKind, _ thread: SecretThread) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                Text(thread.named ? kind.displayName : "Something is going on")
                    .font(.system(.headline, design: .rounded))
                Spacer(minLength: Theme.Spacing.sm)
                SecretStagePips(stage: thread.stage)
            }
            Text(thread.named ? kind.summary : "You do not know what yet. You know it is something.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if thread.named, !people(thread).isEmpty {
                Text(people(thread))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func people(_ thread: SecretThread) -> String {
        let names = thread.employeeIDs.compactMap { engine.state.employee(id: $0)?.name }
        guard !names.isEmpty else { return "" }
        return names.formatted(.list(type: .and))
    }

    @ViewBuilder
    private func closedRow(_ kind: SecretKind, _ thread: SecretThread) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(kind.displayName)
                .font(.system(.headline, design: .rounded))
            Text(thread.endingKind?.displayName ?? "Over")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let last = thread.clues.last {
                Text(last.text)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - The answers

    @ViewBuilder
    private func responses(_ thread: SecretThread) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            ForEach(SecretResponse.allCases, id: \.rawValue) { response in
                SecretResponseRow(
                    response: response,
                    detail: detail(response, thread),
                    refusal: refusal(response),
                    used: thread.hasUsed(response)
                ) {
                    confirming = response
                }
            }
        }
    }

    private func refusal(_ response: SecretResponse) -> String? {
        OfficeSecretsSystem.refusal(response, state: engine.state, balance: engine.balance)?
            .message(engine.balance)
    }

    /// What it costs, on the button, before it is pressed.
    private func detail(_ response: SecretResponse, _ thread: SecretThread) -> String {
        switch response {
        case .investigate:
            return "An evening · names them and brings the next thing forward"
        case .privateEye:
            return "\(engine.balance.officeSecrets.privateEyeCost.money) of your own · everything, at once"
        case .confront:
            return "Free · a conversation you cannot take back"
        case .callHR:
            return "Free · by the book, and the floor hears it went by the book"
        case .makeDeal:
            let cost = OfficeSecretsSystem.dealCost(thread, engine.balance)
            return cost > 0
                ? "\(cost.money) of the company's · it stops"
                : "No cash up front · it stops, on terms"
        case .ignore:
            return "Free · it ends this week, and you chose that"
        // MARK: Iteration 11, wave two — W3 (espionage)
        // The three counterintelligence answers. They only apply to a
        // thread somebody outside is running, and on any other thread the
        // refusal above says so rather than the row disappearing.
        case .sweepOffice:
            return "\(engine.balance.espionage.sweepCost.money) of the company's · "
                + "whatever they left is in a bag by five"
        case .auditRoster:
            return "An evening · the badge log, the payroll, and a name"
        case .feedFalsePlans:
            return "Free · they keep reporting, and you write what they report"
        // MARK: end W3
        }
    }

    private func confirmTitle(_ response: SecretResponse) -> String {
        switch response {
        case .investigate: "Spend an evening on it?"
        case .privateEye: "Put a professional on your own people?"
        case .confront: "Say it to their face?"
        case .callHR: "Hand it to People and HR?"
        case .makeDeal: "Make the problem go away?"
        case .ignore: "Leave it alone?"
        // MARK: W3 (espionage)
        case .sweepOffice: "Have the office swept?"
        case .auditRoster: "Spend an evening on the roster?"
        case .feedFalsePlans: "Write them a quarter of nonsense?"
        // MARK: end W3
        }
    }

    private func confirmBody(_ response: SecretResponse) -> String {
        switch response {
        case .investigate:
            "An evening of asking careful questions. You will come out of it knowing who."
        case .privateEye:
            "They will find everything there is, and you will have paid somebody "
                + "to follow people who work for you."
        case .confront:
            "It becomes a conversation with a person, with two ways it can go, "
                + "and the floor will know by lunch."
        case .callHR:
            "A process rather than a chat. It ends cleanly, on paper, and slowly."
        case .makeDeal:
            "Money, a title or a line on an org chart. Nothing about it is a secret afterwards."
        case .ignore:
            "You know what it is and you are letting it finish. It will finish this week."
        // MARK: W3 (espionage)
        case .sweepOffice:
            "A van, two people and an afternoon of holding things near the walls. "
                + "Whoever put it there will know it is gone."
        case .auditRoster:
            "The badge log against the payroll against the roster, until one line "
                + "does not sit right. It will be somebody you like."
        case .feedFalsePlans:
            "Leave their mole exactly where they are and give them a quarter's "
                + "work in a category that is on its way down."
        // MARK: end W3
        }
    }

    private var dialogPresented: Binding<Bool> {
        Binding(
            get: { confirming != nil },
            set: { presented in if !presented { confirming = nil } }
        )
    }
}

/// Three pips: how far the thing has run before anybody stopped it.
private struct SecretStagePips: View {
    let stage: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(index <= stage ? Theme.warning : Color.secondary.opacity(0.25))
                    .frame(width: 14, height: 4)
            }
        }
        .accessibilityLabel("Stage \(stage + 1) of 3")
    }
}

/// Everything the founder knows, in the order they learned it, with where
/// each one came from.
private struct SecretClueList: View {
    let thread: SecretThread

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            ForEach(thread.clues) { clue in
                HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                    Image(systemName: clue.source.systemImageName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(clue.text)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(clue.source.displayName) · \(GameCalendar(day: clue.day).monthName)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// One answer, with what it costs — or, when it cannot be taken, why not.
private struct SecretResponseRow: View {
    let response: SecretResponse
    let detail: String
    let refusal: String?
    let used: Bool
    let tap: () -> Void

    var body: some View {
        Button(action: tap) {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                Image(systemName: response.systemImageName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(refusal == nil ? Theme.accent : Color.secondary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(response.displayName)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(refusal == nil ? .primary : .secondary)
                    Text(refusal ?? detail)
                        .font(.caption)
                        .foregroundStyle(refusal == nil ? .secondary : Color.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Theme.Spacing.sm)
                if used {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressableRow)
        .disabled(refusal != nil)
        .accessibilityLabel("\(response.displayName). \(refusal ?? detail)")
    }
}

private extension Color {
    /// The refusal line's colour, named here so the row reads.
    static var warning: Color { Theme.warning }
}
