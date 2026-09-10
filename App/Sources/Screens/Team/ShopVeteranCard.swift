import SwiftUI
import TycoonContent
import TycoonEngine

// MARK: - Iteration 13 — P3 (purchases: surfaces and copy)

/// The hire sheet's last row: this fortnight's veteran, drawn as a normal
/// candidate card — face, role, salary, skills and both traits — with the
/// price where *Interview* would be. The exact person is on the card
/// before any money moves (guideline 3.1.1: nothing in the shop is a
/// draw); buying adds exactly them to the pool above.
///
/// Absent when there is no store, no veteran on offer, or the veteran is
/// already in the pool or on the payroll.
struct ShopVeteranRow: View {
    let engine: GameEngine
    let atCap: Bool

    @Environment(\.shopSurface) private var injected
    @State private var pending: ShopSurfaceItem?

    var body: some View {
        if let shop = ShopSurfaceResolver.resolve(injected),
           let veteran = PurchaseRule.veteranOnOffer(state: engine.state, balance: engine.balance, content: engine.content),
           !alreadyHere(veteran) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("A veteran", comment: "Hire sheet: the heading over the one candidate sold through the App Store")
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .textCase(.uppercase)
                    .kerning(0.6)
                    .foregroundStyle(.secondary)
                    .accessibilityAddTraits(.isHeader)
                ShopVeteranCard(engine: engine, veteran: veteran, shop: shop, atCap: atCap, pending: $pending)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .shopDebugScrollTarget("veteran")
            .shopLeaveBoardsDialog(pending: $pending, companyName: engine.state.company.name) { item in
                shop.buy(item)
            }
        }
    }

    /// Bought already: they are a card in the pool, or on the team.
    private func alreadyHere(_ veteran: Candidate) -> Bool {
        engine.state.candidatePool.contains { $0.id == veteran.id }
            || engine.state.employees.contains { $0.appearanceSeed == veteran.appearanceSeed }
    }
}

private struct ShopVeteranCard: View {
    let engine: GameEngine
    let veteran: Candidate
    let shop: any ShopSurfaceModel
    let atCap: Bool
    @Binding var pending: ShopSurfaceItem?

    private var rosterBest: SkillSet {
        let people = engine.state.employees
        return SkillSet(
            coding: people.map(\.skills.coding).max() ?? 0,
            design: people.map(\.skills.design).max() ?? 0,
            marketing: people.map(\.skills.marketing).max() ?? 0
        )
    }

    private var bio: String? {
        if let line = engine.content.dialogue.line(
            for: veteran.traits, mood: 70, context: .hired, seed: veteran.appearanceSeed
        ) {
            return line
        }
        return veteran.traits.first
            .flatMap { id in engine.content.traits.first { $0.id == id } }?
            .bio
    }

    var body: some View {
        let state = engine.state
        let item = ShopSurfaceItem.veteran
        let refusal = ShopSurfaceCopy.refusal(.veteran, state: state)
        let price = shop.price(item.productID)
        let fullOffice = atCap && refusal == nil
        let enabled = refusal == nil && shop.refusal == nil && price != nil && !atCap

        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.md) {
                PixelPortrait(seed: veteran.appearanceSeed)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Text(veteran.name)
                            .font(.system(.headline, design: .rounded))
                            .lineLimit(1)
                        RoleBadge(role: veteran.role, prominent: true)
                    }
                    Text("\(engine.state.standingAsk(for: veteran, balance: engine.balance).money)/wk", comment: "A candidate's weekly salary. wk is short for week")
                        .font(Theme.Typography.number(.caption, weight: .regular))
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                Spacer(minLength: Theme.Spacing.sm)
            }

            if let bio {
                Text("\u{201C}\(bio)\u{201D}")
                    .font(.subheadline)
                    .italic()
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            SkillBars(skills: veteran.skills, reference: rosterBest)

            // Both traits: nobody pays for a CV with a blank on it.
            TraitChipRow(traits: veteran.traits, content: engine.content)

            ShopPriceButton(
                item: item,
                title: String(localized: "Bring them in", comment: "Button on the veteran's card on the hire sheet; the price follows it after a middle dot"),
                price: price,
                refusedWord: refusal?.button,
                enabled: enabled,
                spokenGrant: String(localized: "\(veteran.name), \(veteran.role.displayName), joins the hiring pool at \(engine.state.standingAsk(for: veteran, balance: engine.balance).money) a week", comment: "VoiceOver: what buying the veteran does. Arguments are a name, a role and a weekly salary")
            ) {
                ShopPurchaseFlow.tap(item, state: state, shop: shop, pending: &pending)
            }

            if let footnote = refusal?.footnote ?? shop.refusal {
                caption(footnote, tint: Theme.warning)
            } else if fullOffice {
                caption(String(localized: "Your office is full. Make room before you pay for anyone.", comment: "Under the veteran's disabled button when the office is at its headcount cap"), tint: Theme.warning)
            } else if state.isRanked {
                caption(ShopSurfaceCopy.veteranUnrankingLine, tint: .secondary)
            } else {
                caption(String(localized: "They join the pool above, both traits known. Hiring them is still up to you.", comment: "Under the veteran's button in an unranked company"), tint: .secondary)
            }
        }
        .cardStyle()
    }

    private func caption(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(tint)
            .fixedSize(horizontal: false, vertical: true)
    }
}
