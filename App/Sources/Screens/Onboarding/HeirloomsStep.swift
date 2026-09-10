import SwiftUI
import TycoonContent
import TycoonEngine

// MARK: Iteration 7 — the Heirlooms page (R2)

/// The page after Stakes: one thing from a finished company, or nothing.
/// Shown only when the ledger offers something (`LegacyLedger.offers`);
/// the choice lands on `GameState.newGame(…, heirloom:)` as a pure delta
/// and is spent the moment the company starts. A company that carries an
/// heirloom is unranked, and the page says so before the choice is made.
struct HeirloomsStep: View {
    let ledger: LegacyLedger
    /// For trait names on the people rows.
    let content: ContentCatalog
    @Binding var selection: Heirloom?

    private var offers: [HeirloomOffer] { ledger.offers }

    private var people: [HeirloomOffer] {
        offers.filter { if case .person = $0.heirloom { return true } else { return false } }
    }

    private var perks: [HeirloomOffer] {
        offers.filter { if case .perk = $0.heirloom { return true } else { return false } }
    }

    private var deeds: [HeirloomOffer] {
        offers.filter { if case .deed = $0.heirloom { return true } else { return false } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("One thing from the last company")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                Text("A person, a perk, or the deed. Whatever you take carries once — and a company that carries one never posts to the leaderboards.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            ledgerBanner

            HeirloomRow(
                title: "Carry nothing",
                detail: "Start clean. This company stays ranked.",
                origin: nil,
                isSelected: selection == nil
            ) {
                pick(nil)
            } leading: {
                PixelIconTile(systemImage: "circle.dashed", tint: Theme.pixelInk.opacity(0.6), size: 40)
            }
            .cardStyle()

            if !people.isEmpty {
                PixelSectionTitle(title: "People")
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(people) { offer in
                        if case .person(let person) = offer.heirloom {
                            personRow(person, offer: offer)
                        }
                    }
                }
            }

            if !perks.isEmpty {
                PixelSectionTitle(title: "Perks")
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(perks) { offer in
                        if case .perk(let id) = offer.heirloom {
                            perkRow(id: id, offer: offer)
                        }
                    }
                }
            }

            if !deeds.isEmpty {
                PixelSectionTitle(title: "The deed")
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(deeds) { offer in
                        if case .deed(let deed) = offer.heirloom {
                            deedRow(deed, offer: offer)
                        }
                    }
                }
            }
        }
        .padding(.top, Theme.Spacing.lg)
    }

    // MARK: - Pieces

    /// The hall: how many companies, how many endings, on pixel paper.
    private var ledgerBanner: some View {
        let companies = ledger.runs.count
        let endings = ledger.endingsReached.count
        return PixelPanel {
            HStack(spacing: Theme.Spacing.md) {
                PixelIconTile(systemImage: "gift.fill", size: 48)
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    PixelText(text: "The ledger", scale: 2, color: Theme.pixelAccent, shadow: true)
                    Text("\(companies) \(companies == 1 ? "company" : "companies") · \(endings) of \(GameCenterCatalog.endings.count) endings · \(offers.count) on the table")
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(Theme.pixelInk.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func personRow(_ person: LegacyPerson, offer: HeirloomOffer) -> some View {
        HeirloomRow(
            title: person.name,
            detail: "\(person.resolvedRole.displayName) · rapport \(Int(person.rapport.rounded())). Arrives in your address book, warm; you still hire them at their ask.",
            origin: offer,
            isSelected: selection == offer.heirloom
        ) {
            pick(offer.heirloom)
        } leading: {
            PixelPortrait(seed: person.appearanceSeed, size: 40)
        } extra: {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack(spacing: Theme.Spacing.sm) {
                    SkillStat(label: "Code", value: person.skills.coding, tint: Theme.codePhase)
                    SkillStat(label: "Design", value: person.skills.design, tint: Theme.designPhase)
                    SkillStat(label: "Sales", value: person.skills.marketing, tint: Theme.polishPhase)
                }
                if person.revealedTraits.isEmpty {
                    Text("Traits you never learned")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } else {
                    TraitChipRow(traits: person.revealedTraits, content: content)
                }
            }
        }
        .cardStyle()
    }

    private func perkRow(id: String, offer: HeirloomOffer) -> some View {
        let perk = ProgressionPerk(rawValue: id)
        return HeirloomRow(
            title: perk?.displayName ?? id,
            detail: (perk?.blurb ?? "A permanent perk.") + " From day one.",
            origin: offer,
            isSelected: selection == offer.heirloom
        ) {
            pick(offer.heirloom)
        } leading: {
            PixelIconTile(systemImage: perk?.systemImageName ?? "star.fill", size: 40)
        }
        .cardStyle()
    }

    private func deedRow(_ deed: LegacyDeed, offer: HeirloomOffer) -> some View {
        let tier = deed.tier.rank <= OfficeTier.studio.rank ? deed.tier : .studio
        let capped = tier != deed.tier
        return HeirloomRow(
            title: "The \(deed.district.displayName) \(tier.displayName.lowercased())",
            detail: "Owned outright from day one — no rent, and yours to sell."
                + (capped ? " A \(deed.tier.displayName.lowercased()) carries as a studio; the rest you earn again." : ""),
            origin: offer,
            isSelected: selection == offer.heirloom
        ) {
            pick(offer.heirloom)
        } leading: {
            PixelIconTile(systemImage: "building.2.fill", tint: Theme.pixelInk, size: 40)
        }
        .cardStyle()
    }

    private func pick(_ heirloom: Heirloom?) {
        Haptics.tap()
        Sounds.play(.tap)
        withAnimation(Theme.Motion.selection) { selection = heirloom }
    }
}

/// One selectable heirloom: a leading tile or face, the name, the line
/// about it, where it came from, and the check the origin rows use.
private struct HeirloomRow<Leading: View, Extra: View>: View {
    let title: String
    let detail: String
    /// The company it came from; `nil` on "Carry nothing".
    let origin: HeirloomOffer?
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let extra: () -> Extra

    init(
        title: String, detail: String, origin: HeirloomOffer?, isSelected: Bool,
        action: @escaping () -> Void,
        @ViewBuilder leading: @escaping () -> Leading,
        @ViewBuilder extra: @escaping () -> Extra = { EmptyView() }
    ) {
        self.title = title
        self.detail = detail
        self.origin = origin
        self.isSelected = isSelected
        self.action = action
        self.leading = leading
        self.extra = extra
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                leading()
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(title)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    extra()
                    if let origin {
                        Text("From \(origin.companyName) · \(origin.ending.headline)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.tertiary))
            }
            .padding(Theme.Spacing.md)
            .background(
                isSelected ? Theme.accent.opacity(0.10) : Color.clear,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var accessibilityLabel: String {
        var label = "\(title). \(detail)"
        if let origin { label += " From \(origin.companyName), \(origin.ending.headline)." }
        return label
    }
}

private struct SkillStat: View {
    let label: String
    let value: Double
    let tint: Color

    var body: some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(Int(value.rounded()))")
                .font(Theme.Typography.number(.caption2, weight: .bold))
                .foregroundStyle(tint)
        }
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, 3)
        .background(tint.opacity(0.12), in: Capsule())
        .accessibilityLabel("\(label) \(Int(value.rounded()))")
    }
}

#if DEBUG
#Preview {
    ScrollView {
        HeirloomsStep(
            ledger: .sample,
            content: (try? ContentCatalog.loadBundled()) ?? .init(
                productTypes: [], topics: [], techTree: [], events: [],
                names: NamePools(firstNames: [], lastNames: [], clientCompanies: [])
            ),
            selection: .constant(nil)
        )
        .padding(.horizontal, Theme.Spacing.lg)
    }
    .background(Theme.screenBackground)
}
#endif
