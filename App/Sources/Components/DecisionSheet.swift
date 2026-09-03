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

        init(
            label: String,
            detail: String? = nil,
            role: ButtonRole? = nil,
            cashDelta: Int? = nil,
            action: GameAction
        ) {
            self.label = label
            self.detail = detail
            self.role = role
            self.cashDelta = cashDelta
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
    var kicker: String = "DECISION"
    /// Who is asking, when it is a person: a rival founder or a member of
    /// the team, drawn with the same sprite the rest of the game uses.
    var portraitSeed: UInt64?
    /// Whether the player may put this off. Only story beats: the engine
    /// answers those itself at the deadline, so leaving one on the rail
    /// with a countdown is a real choice. Offers and notices stay modal.
    var isDeferrable = false
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
                postpone: prompt.isDeferrable ? { shell.postpone(prompt, engine: engine) } : nil
            )
            .background(Theme.screenBackground)
        }
        // Medium by default, draggable to full height. At accessibility
        // sizes the medium detent left the title clipped behind the
        // buttons, so the sheet opens full.
        .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.medium, .large])
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

    @Environment(\.dynamicTypeSize) private var typeSize

    /// At accessibility sizes three buttons are most of the screen, and
    /// pinning them leaves the question a hundred points to live in. There
    /// the answers scroll with the copy as one column; everywhere else
    /// they stay put under it.
    private var pinsAnswers: Bool { !typeSize.isAccessibilitySize }

    var body: some View {
        // The question scrolls and the answers stay put in the bottom
        // inset: a two-sentence body plus the deadline's answer does not
        // fit a half sheet, and clipping the sentence that says what
        // silence costs is the worst thing to lose.
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
        if let seed = prompt.portraitSeed {
            PixelPortrait(seed: seed, size: 64)
                .padding(4)
                .background(Theme.pixelPaper)
                .overlay {
                    PixelPanelBorder(thickness: 3, corner: 3)
                        .fill(Theme.pixelInk)
                }
                .accessibilityHidden(true)
        } else {
            PixelIconTile(systemImage: prompt.systemImage, tint: prompt.tint)
        }
    }

    private var answers: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ForEach(prompt.options) { option in
                Button {
                    choose(option)
                } label: {
                    optionLabel(option)
                }
                .buttonStyle(
                    PixelButtonStyle(fill: option.role == .destructive ? Theme.negativeCash : Theme.pixelAccent)
                )
            }

            if let postpone {
                Button {
                    postpone()
                } label: {
                    VStack(spacing: 2) {
                        Text("Let me think")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        Text("The clock runs on; it answers itself at the deadline.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
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
            "in the red"
        } else if burn <= 0 {
            "no burn"
        } else {
            "runway \(after / burn) wk"
        }
        return "\(signed) → \(after.money) · \(runway)"
    }
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
        if let poach = state.rivals.pendingPoach {
            return poachPrompt(poach, state: state)
        }
        if let buyout = state.rivals.pendingBuyout {
            return buyoutPrompt(buyout, state: state, balance: balance)
        }
        if let staffEvent = state.pendingStaffEvent {
            return staffEventPrompt(staffEvent, state: state, content: content, balance: balance)
        }
        // Somebody handed in notice. It is a critical pause with a
        // deadline and a real answer, so it has to reach a sheet.
        if let resignation = state.economy.pendingResignation {
            return resignationPrompt(resignation, state: state, balance: balance)
        }
        // A term sheet pauses the clock, so the question has to be on
        // screen whatever tab the player was on.
        if let offer = state.investors.pendingOffer {
            return investmentPrompt(offer, state: state, content: content)
        }
        return NarrativeChoicePresenter.prompt(for: state, content: content, balance: balance)
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
        let supportLabel = def?.supportive?.label ?? "Be supportive"
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
        let strictLabel = def?.strict.label ?? "Business first"
        let strictDetail = def?.strict.detail ?? "Free, but loyalty takes a hit"

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
                label: "…and make that the rule",
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
                ("Morale", "\(Int(employee.morale.rounded()))"),
                ("Loyalty", "\(Int(employee.loyalty.rounded()))"),
            ],
            options: options,
            kicker: "STAFF",
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
                label: "Raise them to \(raise.money)/wk",
                detail: "Up from \(resignation.salaryAtNotice.money) — enough to keep them",
                action: .adjustSalary(employeeID: employee.id, weeklySalary: raise)
            )
        ]
        if let next = employee.level.next {
            options.append(
                Option(
                    label: "Promote to \(next.displayName)",
                    detail: "A title and the raise that comes with it",
                    action: .promote(employeeID: employee.id)
                )
            )
        }
        options.append(
            Option(
                label: "Let them go",
                detail: "They clear their desk today. Their friends will notice.",
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
                ("On", "\(resignation.salaryAtNotice.money)/wk"),
                ("Answer within", daysLeft == 0 ? "today" : "\(daysLeft) day\(daysLeft == 1 ? "" : "s")"),
            ],
            options: options,
            kicker: "NOTICE",
            portraitSeed: employee.appearanceSeed
        )
    }

    /// An investor's term sheet: what they pay, what they take, and
    /// whether they'll be in the room afterwards.
    private static func investmentPrompt(
        _ offer: InvestmentOffer,
        state: GameState,
        content: ContentCatalog
    ) -> DecisionPrompt? {
        let persona = content.investors.first { $0.id == offer.investorID }
        let boardLine = offer.takesBoardSeat
            ? "They take a board seat and will grade you on \(offer.expects.displayName.lowercased()) every quarter."
            : "No board seat — they wire the money and leave you alone."
        return DecisionPrompt(
            id: "investment-\(offer.investorID)-\(offer.respondByDay)",
            systemImage: "doc.text.fill",
            tint: Theme.accent,
            title: "\(offer.investorName) wants in",
            message: (persona?.pitch.map { "\u{201C}\($0)\u{201D} " } ?? "")
                + "\(offer.amount.money) for \(offer.equity.oneDecimal)% of \(state.company.name). "
                + boardLine,
            stats: [
                ("Cheque", offer.amount.money),
                ("Equity", "\(offer.equity.oneDecimal)%"),
            ],
            options: [
                Option(
                    label: "Take the money",
                    detail: offer.takesBoardSeat
                        ? "Cash in, \(offer.equity.oneDecimal)% out, a board to answer to"
                        : "Cash in, \(offer.equity.oneDecimal)% out",
                    cashDelta: offer.amount,
                    action: .acceptInvestment
                ),
                Option(
                    label: "Stay independent",
                    detail: "Keep all \(state.investors.equityRemaining.oneDecimal)% of it",
                    action: .declineInvestment
                ),
            ],
            kicker: "TERM SHEET"
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
        }
    }

    private static func poachPrompt(_ offer: PoachOffer, state: GameState) -> DecisionPrompt? {
        guard let employee = state.employee(id: offer.employeeID) else { return nil }
        let rival = state.rivals.rival(id: offer.rivalID)
        let rivalName = rival?.name ?? "A rival"
        return DecisionPrompt(
            id: "poach-\(offer.employeeID.uuidString)-\(offer.respondByDay)",
            systemImage: "person.fill.questionmark",
            tint: Theme.warning,
            title: "\(rivalName) wants \(employee.name)",
            message: "They're offering \(offer.offeredWeeklySalary.money)/wk (currently \(employee.weeklySalary.money)/wk). Match it, or let \(employee.name) walk — they'll stay in your address book at that number, and people come back.",
            stats: [
                ("Offer", "\(offer.offeredWeeklySalary.money)/wk"),
                ("Loyalty", "\(Int(employee.loyalty.rounded()))"),
                ("Bond", "\(Int(employee.founderBond.rounded()))"),
            ],
            options: [
                Option(
                    label: "Match the offer",
                    detail: "Raise salary to \(offer.offeredWeeklySalary.money)/wk",
                    action: .matchPoachOffer
                ),
                Option(
                    label: "Let them go — you'll see them again",
                    detail: "\(employee.name) joins \(rivalName) and goes into your address book",
                    role: .destructive,
                    action: .declinePoachOffer
                ),
            ],
            kicker: "POACH",
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
        let rivalName = rival?.name ?? "A rival"
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
            label: "Decline",
            detail: "Keep building",
            action: .declineBuyout
        ))

        return DecisionPrompt(
            id: "buyout-\(offer.rivalID.uuidString)-\(offer.respondByDay)",
            systemImage: strategic ? "envelope.badge.fill" : "tag.fill",
            tint: strategic ? Theme.accent : Theme.warning,
            title: "\(rivalName) wants to buy you out",
            message: message,
            stats: [
                ("Offer", offer.amount.money),
                ("Kind", strategic ? "strategic" : "distress"),
            ],
            options: options,
            kicker: strategic ? "BUYOUT OFFER" : "DISTRESS BID",
            portraitSeed: rival?.appearanceSeed
        )
    }
}
