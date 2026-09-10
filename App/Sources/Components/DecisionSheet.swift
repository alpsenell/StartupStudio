import SwiftUI
import TycoonContent
import TycoonEngine

/// A pause-and-choose moment surfaced from pending state (a rival's poach
/// or buyout offer, a staff moment, a resignation, a term sheet, a story
/// beat). The id is derived from the underlying offer so a new offer
/// re-presents the sheet.
struct DecisionPrompt: Identifiable {
    struct Option: Identifiable {
        let id = UUID()
        let label: String
        /// One-line consequence shown under the label.
        let detail: String?
        let role: ButtonRole?
        let action: GameAction
        /// Lump-sum effect on the company's cash, when the option has one.
        /// The sheet turns it into "−$2,300 → $9,250 · runway 8 wk", which
        /// is the arithmetic a new founder cannot do with the HUD hidden.
        let cashDelta: Int?
        /// Why the option is shown but cannot be taken — "No evenings left
        /// this week" (WS-E). The sheet draws it greyed with the reason
        /// under it: an answer the founder *could* have given is worth
        /// more on the sheet than off it. `nil` for an open option.
        let disabledReason: String?

        init(
            label: String,
            detail: String? = nil,
            role: ButtonRole? = nil,
            cashDelta: Int? = nil,
            disabledReason: String? = nil,
            action: GameAction
        ) {
            self.label = label
            self.detail = detail
            self.role = role
            self.cashDelta = cashDelta
            self.disabledReason = disabledReason
            self.action = action
        }
    }

    let id: String
    let systemImage: String
    let tint: Color
    let title: String
    let message: String
    let stats: [(label: String, value: String)]
    let options: [Option]
    /// The bitmap label over the title: "BUYOUT OFFER", "TERM SHEET",
    /// "STORY". The sheet's first word, in the game's own hand.
    var kicker: String = String(localized: "DECISION", comment: "Bitmap kicker over a decision sheet. Uppercase, and only A-Z since the pixel face has no lowercase")
    /// Who is asking, when it is a person: a rival founder or a member of
    /// the team, drawn with the same sprite the rest of the game uses.
    var portraitSeed: UInt64?
    /// Whether the player may put this off. Only story beats: the engine
    /// answers those itself at the deadline, so leaving one on the rail
    /// with a countdown is a real choice. Offers and notices stay modal.
    var isDeferrable = false
    // MARK: K4 (deals and exits)
    /// The wait answer's own words where "Let me think" is not what waiting
    /// means — the sell-up sheet's *Ride it*. `nil` everywhere else.
    var dealPostponeLabel: String?
    var dealPostponeDetail: String?
    // MARK: end K4
}

/// The reusable modal for `DecisionPrompt`s, presented at the app root so
/// the offer surfaces on whatever tab is frontmost. The timeline is paused
/// while one is up. A deferrable prompt may be pulled down — that is "let
/// me think" — everything else has to be answered with a button.
struct DecisionSheet: View {
    let prompt: DecisionPrompt
    let engine: GameEngine

    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// See `GameShell.shared`: read optionally, because SwiftUI
    /// updates this property for presented content before the
    /// environment is installed and the non-optional form traps there.
    private var shell: GameShell { injectedShell ?? .shared }
    @Environment(\.dynamicTypeSize) private var typeSize

    // MARK: U1 (ux: the first-hour fixes)
    /// C4: the detent the sheet is at. A prompt with three answers or a
    /// long body opens full (`opensLarge`); the rest open at half height
    /// and can be dragged up. The content reads it to draw the question
    /// compactly at the medium detent.
    @State private var detent: PresentationDetent

    init(prompt: DecisionPrompt, engine: GameEngine) {
        self.prompt = prompt
        self.engine = engine
        _detent = State(initialValue: prompt.opensLarge && !DebugLaunch.opensSheetsAtMedium ? .large : .medium)
    }

    /// At accessibility sizes the sheet only has the full detent.
    private var detentSelection: Binding<PresentationDetent> {
        Binding(
            get: { typeSize.isAccessibilitySize ? .large : detent },
            set: { detent = $0 }
        )
    }
    // MARK: end U1

    var body: some View {
        NavigationStack {
            DecisionSheetContent(
                prompt: prompt,
                engine: engine,
                choose: { option in
                    // The answer to a paused question gets a line of its
                    // own, so even an option the reducer applies silently
                    // is acknowledged.
                    shell.toasts.send(
                        option.action,
                        to: engine,
                        ack: option.label,
                        icon: prompt.systemImage,
                        tint: prompt.tint
                    )
                },
                postpone: prompt.isDeferrable ? { shell.postpone(prompt, engine: engine) } : nil,
                // MARK: U1 (ux: the first-hour fixes)
                isCompact: !typeSize.isAccessibilitySize && detent == .medium,
                expand: { withAnimation(Theme.Motion.entrance) { detent = .large } }
                // MARK: end U1
            )
            .background(Theme.screenBackground)
        }
        // Medium by default, draggable to full height; three answers or a
        // long body open full (U1, C4). At accessibility sizes the medium
        // detent left the title clipped behind the buttons, so the sheet
        // only opens full.
        .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.medium, .large], selection: detentSelection)
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(!prompt.isDeferrable)
        .onAppear {
            // A stopped clock deserves a sound. Every prompt here is a
            // critical pause; the toast layer never fires for them.
            Haptics.warning()
            Sounds.play(.warning)
        }
    }
}

/// The sheet's content, separated from its presentation so the snapshot
/// tests can draw it without a live engine paused on a tick.
struct DecisionSheetContent: View {
    let prompt: DecisionPrompt
    let engine: GameEngine
    let choose: (DecisionPrompt.Option) -> Void
    /// Present only for deferrable prompts.
    let postpone: (() -> Void)?
    // MARK: U1 (ux: the first-hour fixes)
    /// C4: the sheet is at its medium detent — the portrait shrinks to 48
    /// points and the body keeps its first two lines. `false` draws the
    /// full question (the large detent, and the snapshot suite).
    var isCompact = false
    /// C4: a tap on the clipped body takes the sheet to full height.
    var expand: (() -> Void)? = nil
    // MARK: end U1

    @Environment(\.dynamicTypeSize) private var typeSize

    /// At accessibility sizes three buttons are most of the screen, and
    /// pinning them leaves the question a hundred points to live in. There
    /// the answers scroll with the copy as one column; everywhere else
    /// they stay put under it.
    private var pinsAnswers: Bool { !typeSize.isAccessibilitySize }

    var body: some View {
        // MARK: U1 (ux: the first-hour fixes)
        // C4: with the answers pinned, the question is pinned too — the
        // portrait, the kicker, the title and the body's first lines sit
        // above the scroll view, so three long answers can never push the
        // title out of a half sheet. Only the stats scroll.
        if pinsAnswers {
            pinnedQuestion
        } else {
            scrollingQuestion
        }
        // MARK: end U1
    }

    // MARK: U1 (ux: the first-hour fixes)
    /// Three answers do not fit under the question in a half sheet. When
    /// the founder drags such a sheet down, the answers scroll under the
    /// pinned question instead of pushing it off the top.
    private var answersScroll: Bool {
        isCompact && prompt.options.count >= 3
    }

    private var pinnedQuestion: some View {
        VStack(spacing: 0) {
            question
                .padding(.top, isCompact ? Theme.Spacing.lg : Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.md)
                .layoutPriority(1)
            ScrollView {
                VStack(spacing: 0) {
                    if !prompt.stats.isEmpty {
                        stats
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.sm)
                    }
                    if answersScroll {
                        answers
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(maxWidth: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !answersScroll {
                answers
            }
        }
    }

    /// The question itself: who is asking, the kicker, the title — which
    /// never truncates — and the body, two lines at the medium detent.
    private var question: some View {
        VStack(spacing: isCompact ? Theme.Spacing.sm : Theme.Spacing.lg) {
            header

            PixelText(text: prompt.kicker, scale: 2, color: Theme.pixelAccent)
                .accessibilityHidden(true)

            VStack(spacing: Theme.Spacing.sm) {
                Text(prompt.title)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if !prompt.message.isEmpty {
                    Text(prompt.message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(isCompact ? 2 : nil)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard isCompact, let expand else { return }
                            Haptics.tap()
                            expand()
                        }
                        .accessibilityHint(isCompact ? "Shows the whole question" : "")
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
        }
    }

    private var stats: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ForEach(Array(prompt.stats.enumerated()), id: \.offset) { _, stat in
                StatPill(systemImage: "circle.fill", value: "\(stat.label) \(stat.value)")
            }
        }
    }
    // MARK: end U1

    /// Accessibility sizes: the question and the answers as one scrolling
    /// column, as the sheet always drew them there.
    private var scrollingQuestion: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                header

                PixelText(text: prompt.kicker, scale: 2, color: Theme.pixelAccent)
                    .accessibilityHidden(true)

                VStack(spacing: Theme.Spacing.sm) {
                    Text(prompt.title)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .multilineTextAlignment(.center)
                    // A prompt with nothing to add beyond its title shows
                    // its title once, not twice.
                    if !prompt.message.isEmpty {
                        Text(prompt.message)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)

                if !prompt.stats.isEmpty {
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(Array(prompt.stats.enumerated()), id: \.offset) { _, stat in
                            StatPill(systemImage: "circle.fill", value: "\(stat.label) \(stat.value)")
                        }
                    }
                }

                if !pinsAnswers {
                    answers
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.xl)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if pinsAnswers {
                answers
            }
        }
    }

    /// The person asking, or the category's icon on a pixel tile.
    @ViewBuilder
    private var header: some View {
        // U1 (C4): 48 points at the medium detent, 64 at full height.
        if let seed = prompt.portraitSeed {
            PixelPortrait(seed: seed, size: isCompact ? 48 : 64)
                .padding(4)
                .background(Theme.pixelPaper)
                .overlay {
                    PixelPanelBorder(thickness: 3, corner: 3)
                        .fill(Theme.pixelInk)
                }
                .accessibilityHidden(true)
        } else {
            PixelIconTile(systemImage: prompt.systemImage, tint: prompt.tint, size: isCompact ? 48 : 64)
        }
    }

    private var answers: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ForEach(prompt.options) { option in
                VStack(spacing: Theme.Spacing.xs) {
                    Button {
                        choose(option)
                    } label: {
                        optionLabel(option)
                    }
                    .buttonStyle(
                        PixelButtonStyle(fill: option.role == .destructive ? Theme.negativeCash : Theme.pixelAccent)
                    )
                    // A greyed option stays on the sheet: the founder
                    // sees the evening they no longer have.
                    .disabled(option.disabledReason != nil)
                    .opacity(option.disabledReason == nil ? 1 : 0.4)
                    .accessibilityHint(option.disabledReason ?? "")

                    if let reason = option.disabledReason {
                        Text(reason)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.warning)
                            .multilineTextAlignment(.center)
                            .accessibilityHidden(true)
                    }
                }
            }

            if let postpone {
                Button {
                    postpone()
                } label: {
                    VStack(spacing: 2) {
                        // MARK: K4 (deals and exits)
                        // A prompt may name what waiting means (*Ride it*).
                        Group {
                            if let label = prompt.dealPostponeLabel { Text(label) } else { Text("Let me think") }
                        }
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        Group {
                            if let detail = prompt.dealPostponeDetail {
                                Text(detail)
                            } else {
                                Text("The clock runs on; it answers itself at the deadline.")
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        // MARK: end K4
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.sm)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.pressableRow)
                .foregroundStyle(Theme.accent)
                .accessibilityHint("Closes the question and resumes time; it stays on the notice rail with its deadline")
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.top, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.xl)
        .background(Theme.screenBackground)
    }

    private func optionLabel(_ option: DecisionPrompt.Option) -> some View {
        VStack(spacing: 2) {
            Text(option.label)
                .font(.system(.headline, design: .rounded))
            if let detail = option.detail {
                Text(detail)
                    .font(.caption)
                    .opacity(0.85)
            }
            if let delta = option.cashDelta {
                Text(afterState(delta))
                    .font(.caption2.monospacedDigit())
                    .opacity(0.9)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xs)
    }

    /// "−$2,300 → $9,250 · runway 8 wk": what the company looks like after
    /// this option, from the same numbers the HUD shows.
    private func afterState(_ delta: Int) -> String {
        DecisionPrompt.afterState(delta: delta, cash: engine.state.company.cash, burn: engine.weeklyBurn)
    }
}

extension DecisionPrompt {
    /// The money line under an answer — "−$2,300 → $9,250 · runway 8 wk"
    /// — from the same numbers the HUD shows. Shared with every confirm
    /// that spends the company's cash, so the arithmetic reads the same
    /// on a sheet and in a dialog.
    static func afterState(delta: Int, cash: Int, burn: Int) -> String {
        let after = cash + delta
        let signed = delta >= 0 ? "+" + delta.money : delta.money
        let runway: String = if after < 0 {
            String(localized: "in the red", comment: "Runway readout when cash is below zero. Lower case: it is dropped into a line, not a heading")
        } else if burn <= 0 {
            String(localized: "no burn", comment: "Runway readout when the company spends nothing. Lower case: it is dropped into a line, not a heading")
        } else {
            String(localized: "runway \(after / burn) wk", comment: "Runway readout under an answer: weeks of cash left afterwards")
        }
        return "\(signed) → \(after.money) · \(runway)"
    }

    // MARK: U1 (ux: the first-hour fixes)
    /// C4: three answers, or a body past about 120 characters, do not fit
    /// a half sheet with the question still on it, so the sheet opens full.
    var opensLarge: Bool {
        options.count >= 3 || message.count > 120
    }
    // MARK: end U1
}

// MARK: - Prompt mapping

extension DecisionPrompt {
    /// The prompt for whatever offer is pending, poach first. Reads pending
    /// state (not transient events) so an offer survives app relaunches.
    /// Story beats come last, through `NarrativeChoicePresenter`.
    static func pending(
        in state: GameState,
        content: ContentCatalog,
        balance: BalanceConfig
    ) -> DecisionPrompt? {
        // MARK: J6 (queue)
        // One queue for every question: the first sheet in `QueueBoard`'s
        // order. A new kind of sheet goes in `queuePrompt(for:)` below.
        queue(in: state, content: content, balance: balance).first
        // MARK: end J6
    }

    /// The staff moment on screen. Wording, both answers and their
    /// consequence lines come from `StaffEvents.json`; a kind with no
    /// definition falls back to the generic phrasing and the balance's
    /// support cost, which is what the two original kinds used.
    ///
    /// A policy-shaped kind (WS-D) says so on its generous answer — it
    /// becomes the rule — and offers the firm answer twice: once for this
    /// person, and once as the rule for everyone who asks after them.
    private static func staffEventPrompt(
        _ event: StaffEvent,
        state: GameState,
        content: ContentCatalog,
        balance: BalanceConfig
    ) -> DecisionPrompt? {
        guard let employee = state.employee(id: event.employeeID) else { return nil }
        let social = balance.social
        let def = content.staffEvent(event.definitionID)

        func fill(_ text: String) -> String {
            text
                .replacingOccurrences(of: "{name}", with: employee.name)
                .replacingOccurrences(of: "{company}", with: state.company.name)
        }

        let title = def.map { fill($0.title) }
            ?? "\(employee.name) needs an answer"
        let message = def.map { fill($0.body) }
            ?? "They came to you with something. Back them, or hold the line."
        // A rolled kind with a policy block can become a rule; a second
        // act never can, and neither can a kind that already has one.
        let policy = event.defID == nil && state.staffMemory.policy(for: event.kind) == nil
            ? def?.policy
            : nil
        let supportLabel = def?.supportive?.label ?? String(localized: "Be supportive", comment: "Default generous answer to a staff question when the catalog has none")
        var supportDetail = def?.supportive?.detail
            ?? "Costs \(social.supportCost.money) · loyalty way up"
        if policy != nil { supportDetail += " · becomes the rule" }
        // The def's own cash cost, so the after-state on the button is
        // the number the ledger will show; the generic support cost only
        // for a kind the catalog does not describe.
        let supportCash: Int? = if let def {
            def.supportive.map(\.cash).flatMap { $0 != 0 ? $0 : nil }
        } else {
            social.supportCost > 0 ? -social.supportCost : nil
        }
        let strictLabel = def?.strict.label ?? String(localized: "Business first", comment: "Default firm answer to a staff question when the catalog has none")
        let strictDetail = def?.strict.detail ?? String(localized: "Free, but loyalty takes a hit", comment: "Default detail under the firm answer to a staff question")

        var options = [
            Option(
                label: supportLabel,
                detail: supportDetail,
                cashDelta: supportCash,
                action: .resolveStaffEvent(choice: .supportive)
            ),
            Option(
                label: strictLabel,
                detail: strictDetail,
                role: .destructive,
                action: .resolveStaffEvent(choice: .strict)
            ),
        ]
        if let policy {
            options.append(Option(
                label: String(localized: "…and make that the rule", comment: "Third answer to a staff question: apply the firm answer to everyone from now on"),
                detail: "\(policy.name): the same answer for everyone who asks · no sheet next time",
                role: .destructive,
                action: .resolveStaffEvent(choice: .strictAsPolicy)
            ))
        }

        return DecisionPrompt(
            id: "staff-\(event.employeeID.uuidString)-\(event.respondByDay)",
            systemImage: staffIcon(for: event.kind),
            tint: Theme.warning,
            title: title,
            message: message,
            stats: [
                (String(localized: "Morale", comment: "Decision sheet stat: how the person feels about the job"), "\(Int(employee.morale.rounded()))"),
                (String(localized: "Loyalty", comment: "Decision sheet stat: how likely the person is to stay"), "\(Int(employee.loyalty.rounded()))"),
            ],
            options: options,
            kicker: String(localized: "STAFF", comment: "Bitmap kicker: someone on the team is asking. Uppercase A-Z only"),
            portraitSeed: employee.appearanceSeed
        )
    }

    /// Somebody is leaving unless the founder answers. A counter counts as
    /// enough when it clears `counterOfferRaiseFactor` on the salary they
    /// were on at notice, or when it is a promotion — so those are the two
    /// answers, and the third is letting them go, which is the only other
    /// thing that clears the notice.
    private static func resignationPrompt(
        _ resignation: PendingResignation,
        state: GameState,
        balance: BalanceConfig
    ) -> DecisionPrompt? {
        guard let employee = state.employee(id: resignation.employeeID) else { return nil }
        let raise = Int(
            (Double(resignation.salaryAtNotice) * balance.economy.counterOfferRaiseFactor)
                .rounded(.up)
        )
        let daysLeft = max(0, resignation.respondByDay - state.day)
        var options: [Option] = [
            Option(
                label: String(localized: "Raise them to \(raise.money)/wk", comment: "Answer to a resignation: pay this much a week instead"),
                detail: "Up from \(resignation.salaryAtNotice.money) — enough to keep them",
                action: .adjustSalary(employeeID: employee.id, weeklySalary: raise)
            )
        ]
        if let next = employee.level.next {
            options.append(
                Option(
                    label: String(localized: "Promote to \(next.displayName)", comment: "Answer to a resignation: move them to the next seniority"),
                    detail: String(localized: "A title and the raise that comes with it", comment: "Detail under the promote answer to a resignation"),
                    action: .promote(employeeID: employee.id)
                )
            )
        }
        options.append(
            Option(
                label: String(localized: "Let them go", comment: "Answer to a resignation: accept it"),
                detail: String(localized: "They clear their desk today. Their friends will notice.", comment: "Detail under the let-them-go answer to a resignation"),
                role: .destructive,
                action: .fire(employeeID: employee.id)
            )
        )
        return DecisionPrompt(
            id: "resignation-\(resignation.employeeID)-\(resignation.sinceDay)",
            systemImage: "figure.walk.departure",
            tint: Theme.warning,
            title: "\(resignation.name) is leaving",
            message: "\(resignation.name) has handed in notice after "
                + "\(state.day - employee.hiredDay) days at \(state.company.name). "
                // A notice that is the second act of an answer says so
                // (WS-D); one that morale alone explains says nothing more.
                + (resignation.reason.map { "\($0) " } ?? "")
                + "A real raise or a promotion still turns it around — "
                + "anything less and they walk.",
            stats: [
                (String(localized: "On", comment: "Decision sheet stat label: the salary the leaver is on"), "\(resignation.salaryAtNotice.money)/wk"),
                (String(localized: "Answer within", comment: "Decision sheet stat label: how long is left to reply"), daysLeft == 0 ? "today" : "\(daysLeft) day\(daysLeft == 1 ? "" : "s")"),
            ],
            options: options,
            kicker: String(localized: "NOTICE", comment: "Bitmap kicker: somebody has handed in notice. Uppercase A-Z only"),
            portraitSeed: employee.appearanceSeed
        )
    }

    /// An investor's term sheet: what they pay, what they take, and
    /// whether they'll be in the room afterwards.
    private static func investmentPrompt(
        _ offer: InvestmentOffer,
        state: GameState,
        content: ContentCatalog,
        // MARK: J2 (record)
        balance: BalanceConfig
        // MARK: end J2
    ) -> DecisionPrompt? {
        let persona = content.investors.first { $0.id == offer.investorID }
        var boardLine = offer.takesBoardSeat
            ? "They take a board seat and will grade you on \(offer.expects.displayName.lowercased()) every quarter."
            : "No board seat — they wire the money and leave you alone."
        // MARK: J2 (record)
        // The sheet says so: it arrived while a case was open and nobody
        // sat on the board to read the papers first.
        if offer.standingKeyPersonClause {
            let cut = Int(((1 - balance.founderStanding.keyPersonClauseFactor) * 100).rounded())
            boardLine += " Key-person clause: −\(cut)%. They read about the case."
        }
        // MARK: end J2
        // WS-G: signing is the one-way declaration. Said once, on the
        // button, while there is still something to give up.
        let oneWay = state.investors.equityRemaining >= 100
            ? " You stop being independent — the Still yours ending closes."
            : ""
        return DecisionPrompt(
            id: "investment-\(offer.investorID)-\(offer.respondByDay)",
            systemImage: "doc.text.fill",
            tint: Theme.accent,
            title: "\(offer.investorName) wants in",
            message: (persona?.pitch.map { "\u{201C}\($0)\u{201D} " } ?? "")
                + "\(offer.amount.money) for \(offer.equity.oneDecimal)% of \(state.company.name). "
                + boardLine,
            stats: [
                (String(localized: "Cheque", comment: "Decision sheet stat label: the money an investor is offering"), offer.amount.money),
                (String(localized: "Equity", comment: "Decision sheet stat label: the share of the company being asked for"), "\(offer.equity.oneDecimal)%"),
            ],
            options: [
                Option(
                    label: String(localized: "Take the money", comment: "Answer to a term sheet: accept the investment"),
                    detail: (offer.takesBoardSeat
                        ? "Cash in, \(offer.equity.oneDecimal)% out, a board to answer to."
                        : "Cash in, \(offer.equity.oneDecimal)% out.") + oneWay,
                    cashDelta: offer.amount,
                    action: .acceptInvestment
                ),
                Option(
                    label: String(localized: "Stay independent", comment: "Answer to a term sheet: turn the investment down"),
                    detail: "Keep all \(state.investors.equityRemaining.oneDecimal)% of it",
                    action: .declineInvestment
                ),
            ],
            kicker: String(localized: "TERM SHEET", comment: "Bitmap kicker: an investor is offering money. Uppercase A-Z only")
        )
    }

    /// The symbol for a staff kind, shared with the policies card.
    static func staffIcon(for kind: StaffEventKind) -> String {
        switch kind {
        case .familyEmergency: "heart.text.square.fill"
        case .rivalOfferRumor: "person.fill.questionmark"
        case .raiseRequest, .promotionDemand: "arrow.up.forward.circle.fill"
        case .roleSwitch: "arrow.triangle.swap"
        case .teamConflict: "person.2.slash.fill"
        case .burnoutWarning: "moon.zzz.fill"
        case .sideProject: "lightbulb.fill"
        case .parentalLeave: "figure.and.child.holdinghands"
        case .remoteRequest: "airplane.departure"
        case .harassmentComplaint: "exclamationmark.shield.fill"
        // MARK: Iteration 11 — N5 (office secrets)
        // The six confrontations. Each borrows the icon its thread wears
        // on the Team tab, so the sheet and the card read as one thing.
        case .officeMole: "doc.on.doc.fill"
        case .officeRomance: "heart.slash.fill"
        case .officeExpenses: "creditcard.trianglebadge.exclamationmark"
        case .officeClique: "person.3.sequence.fill"
        case .officeUnion: "figure.stand.line.dotted.figure.stand"
        case .officeCoup: "hand.raised.slash.fill"
        // MARK: end Iteration 11 — N5
        }
    }

    private static func poachPrompt(_ offer: PoachOffer, state: GameState) -> DecisionPrompt? {
        guard let employee = state.employee(id: offer.employeeID) else { return nil }
        let rival = state.rivals.rival(id: offer.rivalID)
        let rivalName = rival?.name ?? String(localized: "A rival", comment: "Stand-in for a rival studio whose name could not be resolved")
        return DecisionPrompt(
            id: "poach-\(offer.employeeID.uuidString)-\(offer.respondByDay)",
            systemImage: "person.fill.questionmark",
            tint: Theme.warning,
            title: "\(rivalName) wants \(employee.name)",
            message: "They're offering \(offer.offeredWeeklySalary.money)/wk (currently \(employee.weeklySalary.money)/wk). Match it, or let \(employee.name) walk — they'll stay in your address book at that number, and people come back.",
            stats: [
                (String(localized: "Offer", comment: "Decision sheet stat label: what is on the table - a rival salary offer, or a buyout price"), "\(offer.offeredWeeklySalary.money)/wk"),
                (String(localized: "Loyalty", comment: "Decision sheet stat: how likely the person is to stay"), "\(Int(employee.loyalty.rounded()))"),
                (String(localized: "Bond", comment: "Decision sheet stat: how close this person is to the founder"), "\(Int(employee.founderBond.rounded()))"),
            ],
            options: [
                Option(
                    label: String(localized: "Match the offer", comment: "Answer to a poach: pay what the rival offered"),
                    detail: "Raise salary to \(offer.offeredWeeklySalary.money)/wk",
                    action: .matchPoachOffer
                ),
                Option(
                    label: String(localized: "Let them go — you\'ll see them again", comment: "Answer to a poach: let the person leave for the rival"),
                    detail: "\(employee.name) joins \(rivalName) and goes into your address book",
                    role: .destructive,
                    action: .declinePoachOffer
                ),
            ],
            kicker: String(localized: "POACH", comment: "Bitmap kicker: a rival is trying to hire somebody away. Uppercase A-Z only"),
            portraitSeed: rival?.appearanceSeed
        )
    }

    /// The category fight: the rival's face, the numbers the decision is
    /// made of — your share now, their score against your best, the
    /// weeks until it settles — and answers that are actions the game
    /// already has, routed to the product that holds the category. Only
    /// the answers that would land are offered: a patch needs a free
    /// build slot, a campaign has a cooldown, a budget product cannot go
    /// budget again. "Let it go" is always there, and says what the six
    /// weeks decide either way.
    static func challengePrompt(
        _ challenge: CategoryChallenge,
        state: GameState,
        content: ContentCatalog,
        balance: BalanceConfig
    ) -> DecisionPrompt? {
        let rival = state.rivals.rival(id: challenge.rivalID)
        let rivalName = rival?.name ?? String(localized: "A rival", comment: "Stand-in for a rival studio whose name could not be resolved")
        let topic = content.topic(challenge.topicID)?.name ?? challenge.topicID
        let depth = balance.rivals.depth
        let theirs = Int(challenge.quality.rounded())
        let share = Int((state.rivals.share(for: challenge.topicID) * 100).rounded())
        let holdShare = Int((depth.challengeHoldShare * 100).rounded())
        let daysLeft = max(0, challenge.settlesDay - state.day)
        let weeksLeft = max(1, (daysLeft + 6) / 7)

        // The product that holds the category: the best thing the player
        // has on the market there, which is what the share pass scores.
        let best = state.products
            .compactMap { product -> (product: Product, info: ReleaseInfo)? in
                guard product.topicID == challenge.topicID,
                      case .released(let info) = product.stage,
                      !info.offMarket
                else { return nil }
                return (product, info)
            }
            .max { lhs, rhs in
                if lhs.info.averageReviewScore != rhs.info.averageReviewScore {
                    return lhs.info.averageReviewScore < rhs.info.averageReviewScore
                }
                return lhs.product.id.uuidString > rhs.product.id.uuidString
            }

        var options: [Option] = []
        if let best {
            if best.info.priceTier != .budget {
                options.append(Option(
                    label: String(localized: "Cut the price", comment: "Answer to a category challenge: move the product to the budget tier"),
                    detail: "\(best.product.name) goes budget — more of the market, less per sale",
                    action: .defendCategory(topicID: challenge.topicID, defense: .budgetPrice)
                ))
            }
            if state.hasFreeDevSlot {
                options.append(Option(
                    label: "Patch \(best.product.name)",
                    detail: "Takes a build slot for a few weeks; the press takes another look",
                    action: .defendCategory(topicID: challenge.topicID, defense: .patch)
                ))
            }
            // Mirrors `MarketingSystem.startCampaign`'s repeat guard for
            // the social push (`CampaignKind.socialPush`, "social_push"),
            // so the answer is only offered when the engine would take it.
            let cooldown = max(0, balance.economy.campaignCooldownDays)
            let day = state.day
            let productID = best.product.id
            let campaignBlocked = state.campaigns.contains { campaign in
                guard campaign.kindID == "social_push", campaign.productID == productID else { return false }
                let sinceEnd: Int = day - campaign.endDay
                return sinceEnd < cooldown || campaign.endDay >= day
            }
            if !campaignBlocked {
                let days = balance.socialPushDurationDays
                let cost = balance.socialPushDailyCost * days
                options.append(Option(
                    label: String(localized: "Run a campaign", comment: "Answer to a category challenge: spend on marketing"),
                    detail: "A social push on \(best.product.name), \(cost.money) over \(days) days",
                    cashDelta: -cost,
                    action: .defendCategory(topicID: challenge.topicID, defense: .campaign)
                ))
            }
        }
        options.append(Option(
            label: String(localized: "Let it go", comment: "Answer to a category challenge: do nothing and take what comes"),
            // U1 (C4): "they come out N weaker", not the engine's "strength".
            detail: "Hold \(holdShare)% when it settles and they come out \(Int(depth.heldRivalStrengthLoss)) weaker; "
                + "lose it and your standing here drops \(Int(depth.lostStandingLoss))",
            role: .destructive,
            action: .concedeCategory
        ))

        let yours = best.map { "\($0.info.averageReviewScore)" } ?? "—"
        let against = best.map { "\($0.product.name) scores \($0.info.averageReviewScore)" }
            ?? String(localized: "you have nothing on the market there", comment: "Fills a sentence comparing your product with a rival when you have none in that topic")
        return DecisionPrompt(
            id: "challenge-\(challenge.id)",
            systemImage: "flag.2.crossed.fill",
            tint: Theme.warning,
            title: "\(rivalName) launched into \(topic)",
            message: "\(challenge.productName) scores \(theirs); \(against). "
                + "You hold \(share)% of \(topic) today. In \(weeksLeft) week\(weeksLeft == 1 ? "" : "s") "
                + "whoever holds half of it keeps the category.",
            stats: [
                (String(localized: "Your share", comment: "Decision sheet stat label: the percentage of a topic you hold"), "\(share)%"),
                (String(localized: "Them · you", comment: "Decision sheet stat label: the rival review score against yours"), "\(theirs) · \(yours)"),
                (String(localized: "Settles in", comment: "Decision sheet stat label: when the category fight is decided"), daysLeft == 0 ? "today" : "\(daysLeft)d"),
            ],
            options: options,
            kicker: String(localized: "CHALLENGE", comment: "Bitmap kicker: a rival has launched into one of your topics. Uppercase A-Z only"),
            portraitSeed: rival?.appearanceSeed
        )
    }


    /// A rival's offer for the company. The sheet says plainly which of
    /// the two kinds it is, because they end very differently: a strategic
    /// approach is a premium for something worth having and ends as
    /// *Acquired*; a distress bid is somebody picking up the name and the
    /// desks and ends as *Sold up*, post-mortem and all.
    ///
    /// A strategic offer has a third answer: the earn-out — part of the
    /// price today, the rest over two quarterly reviews with the acquirer
    /// on the board. The button carries the money and the after-state
    /// line, and the detail names the number they will watch, because
    /// that is the whole bet.
    private static func buyoutPrompt(
        _ offer: BuyoutOffer,
        state: GameState,
        balance: BalanceConfig
    ) -> DecisionPrompt? {
        let rival = state.rivals.rival(id: offer.rivalID)
        let rivalName = rival?.name ?? String(localized: "A rival", comment: "Stand-in for a rival studio whose name could not be resolved")
        let strategic = state.rivals.lastBuyoutWasStrategic
        let message = strategic
            ? "A strategic approach: they want what you built, and \(offer.amount.money) is a premium "
                + "on what \(state.company.name) is worth today. Cash today ends the run as an "
                + "acquisition; an earn-out pays part now and the rest if you hit their number."
            : "A distress bid. \(offer.amount.money) buys the name, the desks and whatever is on the "
                + "shelf. Selling ends the run — sold up, not a win."

        var options: [Option] = [
            Option(
                label: strategic ? "Sell for \(offer.amount.money)" : "Sell up for \(offer.amount.money)",
                detail: strategic ? "Cash today · ends the run as Acquired" : "Ends the run as Sold up",
                role: strategic ? nil : .destructive,
                action: .acceptBuyout
            ),
        ]
        if strategic {
            let config = balance.investors
            let upfront = Int((Double(offer.amount) * config.earnOutUpfrontShare).rounded())
            let rest = offer.amount - upfront
            let expectation = state.earnOutExpectation(balance: balance)
            options.append(Option(
                label: "Earn-out — \(upfront.money) now",
                detail: "Up to \(rest.money) more over \(config.earnOutReviews) quarterly reviews if you hit "
                    + "\(expectation.displayName.lowercased()) with \(rivalName) on the board · "
                    + "team morale −\(Int(config.earnOutMoraleCost))",
                cashDelta: upfront,
                action: .acceptBuyoutEarnOut
            ))
        }
        options.append(Option(
            label: String(localized: "Decline", comment: "Answer to a buyout offer: refuse it"),
            detail: String(localized: "Keep building", comment: "Detail under the refuse answer to a buyout offer"),
            action: .declineBuyout
        ))

        return DecisionPrompt(
            id: "buyout-\(offer.rivalID.uuidString)-\(offer.respondByDay)",
            systemImage: strategic ? "envelope.badge.fill" : "tag.fill",
            tint: strategic ? Theme.accent : Theme.warning,
            title: "\(rivalName) wants to buy you out",
            // MARK: K4 (deals and exits) — a bid the sign brought says what was asked.
            message: message + dealListingNote(offer, state: state, balance: balance),
            // MARK: end K4
            stats: [
                (String(localized: "Offer", comment: "Decision sheet stat label: what is on the table - a rival salary offer, or a buyout price"), offer.amount.money),
                (String(localized: "Kind", comment: "Decision sheet stat label: which sort of buyout this is"), strategic ? String(localized: "strategic", comment: "Buyout kind: a buyer who wants what you built") : String(localized: "distress", comment: "Buyout kind: a lowball bid while you are failing")),
            ],
            options: options,
            kicker: strategic ? String(localized: "BUYOUT OFFER", comment: "Bitmap kicker: a rival wants to buy the company. Uppercase A-Z only") : String(localized: "DISTRESS BID", comment: "Bitmap kicker: a lowball offer while the company is failing. Uppercase A-Z only"),
            portraitSeed: rival?.appearanceSeed
        )
    }

    // MARK: J6 (queue)

    /// Iteration 12 — J6. Every question the game is asking, in the
    /// queue's order (`QueueBoard`): a sheet for each one answered with a
    /// button, and for a room the entry alone — the rail walks the founder
    /// into it. Offers, notices, strings and the confrontation used to sit
    /// in a fixed order where the first hid the rest; now the soonest
    /// deadline leads and the others wait behind it, visibly.
    static func queueItems(
        in state: GameState,
        content: ContentCatalog,
        balance: BalanceConfig
    ) -> [QueueItem] {
        QueueBoard.entries(in: state, balance: balance).map { entry in
            QueueItem(
                entry: entry,
                prompt: queuePrompt(for: entry, state: state, content: content, balance: balance)
            )
        }
    }

    /// The sheets alone, in the queue's order.
    static func queue(
        in state: GameState,
        content: ContentCatalog,
        balance: BalanceConfig
    ) -> [DecisionPrompt] {
        queueItems(in: state, content: content, balance: balance).compactMap(\.prompt)
    }

    /// The sheet for one entry. "Let me think" works on every one of them:
    /// each either has a deadline the engine answers for the founder, or
    /// waits for them, so putting it on the rail is always a real choice.
    private static func queuePrompt(
        for entry: QueueEntry,
        state: GameState,
        content: ContentCatalog,
        balance: BalanceConfig
    ) -> DecisionPrompt? {
        guard entry.surface == .sheet else { return nil }
        var prompt: DecisionPrompt? = switch entry.kind {
        case .poach:
            state.rivals.pendingPoach.flatMap { poachPrompt($0, state: state) }
        case .buyout:
            state.rivals.pendingBuyout.flatMap { buyoutPrompt($0, state: state, balance: balance) }
        case .challenge:
            // A rival launched into a category the player holds (WS-A).
            state.rivals.pendingChallenge.flatMap {
                challengePrompt($0, state: state, content: content, balance: balance)
            }
        case .staff:
            state.pendingStaffEvent.flatMap {
                staffEventPrompt($0, state: state, content: content, balance: balance)
            }
        case .resignation:
            state.economy.pendingResignation.flatMap {
                resignationPrompt($0, state: state, balance: balance)
            }
        case .termSheet:
            // J2's key-person clause reads the balance.
            state.investors.pendingOffer.flatMap { investmentPrompt($0, state: state, content: content, balance: balance) }
        case .story:
            NarrativeChoicePresenter.prompt(for: state, content: content, balance: balance)
        case .dirtyMoneyDemand:
            queueDemandPrompt(state: state, balance: balance)
        case .confrontation:
            queueConfrontationPrompt(state: state, balance: balance) // K7: the slice on "Pack a bag"
        case .priceWar:
            // Iteration 12 merge — J3's sheet, seated in J6's queue.
            PriceWarPrompt.pending(in: state, content: content, balance: balance)
        // MARK: K1 (founder money)
        case .rescue:
            founderMoneyRescuePrompt(state: state, balance: balance)
        // MARK: end K1
        // MARK: K4 (deals and exits)
        case .sellUp:
            dealSellUpPrompt(state: state, balance: balance)
        // MARK: end K4
        case .dirtyMoneyOffer, .funeral, .legalCase, .hearing, .cancellation:
            nil
        }
        // The category fight is the one sheet that stays modal: its six
        // weeks are its deadline and the answers are moves in the fight,
        // and `RivalFightSnapshotTests` pins that. Everything else can wait.
        prompt?.isDeferrable = entry.kind != .challenge
        return prompt
    }

    // MARK: end J6
}
