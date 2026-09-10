import Foundation
import TycoonContent

// MARK: K7 (partner and diary)

#if DEBUG
/// `-autoPartner <stage>`: dresses one K7 situation on whatever save is
/// loaded, through the engine, for a screenshot. Debug builds only; nothing
/// in the game sends `.partnerDebugSeed`.
///
/// - `partner`: married for two years, affection 72 — the hire row.
/// - `hired`: the same, the partner on payroll, the company on crunch.
/// - `leave`: hired, the affair on the table — "Pack a bag" with its slice.
/// - `ex`: three years married with the partner on payroll, divorced.
/// - `oldex`: the same, with the settlement as a pre-K7 save wrote it.
/// - `diary`: an anniversary on the date the announce sheet proposes.
/// - `launch`: an anniversary tomorrow and the first build shipped today.
/// - `letter`: doors armed, health 38, the doctor's letter on the table.
enum PartnerDebugSeed {
    static func apply(
        stage: String,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        // `diary:<day>` names the day the app's announce sheet proposes.
        if stage.hasPrefix("diary:"), let day = Int(stage.dropFirst("diary:".count)) {
            marry(&state, days: 700, balance: balance, content: content)
            putAnniversary(on: day + 1, &state)
            return []
        }
        switch stage {
        case "partner":
            marry(&state, days: 700, balance: balance, content: content)
            return []
        case "hired":
            marry(&state, days: 700, balance: balance, content: content)
            state.life.family.affection = 58
            let events = hire(&state, balance: balance)
            state.economy.workPace = .crunch
            return events
        case "leave":
            marry(&state, days: 1100, balance: balance, content: content)
            var events = hire(&state, balance: balance)
            events += FamilyDramaSystem.openRoom(state: &state, balance: balance, content: content)
            state.familyDrama.confrontedDay = state.day
            state.familyDrama.confessionAnswer = nil
            return events
        case "ex", "oldex":
            marry(&state, days: 1100, balance: balance, content: content)
            var events = hire(&state, balance: balance)
            events += FamilyDramaSystem.openRoom(state: &state, balance: balance, content: content)
            events += FamilyDramaSystem.divorce(
                keep: [], lawyer: .dutySolicitor, state: &state, balance: balance, content: content
            )
            if stage == "oldex", let id = state.familyDrama.settlement?.exContactID {
                state.familyDrama.settlement?.exContactID = nil
                state.networking.contacts.removeAll { $0.id == id }
            }
            return events
        case "diary":
            marry(&state, days: 700, balance: balance, content: content)
            guard let product = state.productsInDevelopment.first,
                  let day = state.announceProposal(
                      productID: product.id, slackDays: 14, balance: balance, content: content
                  )
            else { return [] }
            putAnniversary(on: day + 1, &state)
            return []
        case "launch":
            marry(&state, days: 700, balance: balance, content: content)
            guard let product = state.productsInDevelopment.first,
                  let index = state.products.firstIndex(where: { $0.id == product.id }),
                  case .development(var dev) = state.products[index].stage,
                  let type = content.productType(product.typeID)
            else { return [] }
            putAnniversary(on: state.day + 1, &state)
            dev.codePts = max(dev.codePts, type.codePts)
            dev.hype = max(dev.hype, 0.4)
            state.products[index].stage = .development(dev)
            return ProductSystem.ship(productID: product.id, state: &state, balance: balance, content: content)
        case "letter":
            state.doors.armed = true
            state.life.meters.health = min(state.life.meters.health, 38)
            state.narrative.cooldowns[DoctorLetter.eventID] = nil
            state.narrative.scheduled.removeAll { $0.eventID == DoctorLetter.eventID }
            _ = DoctorLetter.check(&state, balance, content)
            if let index = state.narrative.scheduled.firstIndex(where: { $0.eventID == DoctorLetter.eventID }) {
                state.narrative.scheduled[index].day = state.day
            }
            return DoctorLetter.check(&state, balance, content)
        default:
            return []
        }
    }

    private static func marry(
        _ state: inout GameState, days: Int, balance: BalanceConfig, content: ContentCatalog
    ) {
        if state.life.family.stage != .married || state.life.family.partnerAppearanceSeed == nil {
            state.life.family.stage = .married
            state.life.family.stageSinceDay = max(0, state.day - days)
            state.life.family.partnerName = state.life.family.partnerName ?? "Nora Quinn"
            state.life.family.partnerAppearanceSeed = state.life.family.partnerAppearanceSeed
                ?? 0x5EED_0000_2B7C_91A3
            FamilyCalendar.stageChanged(&state, balance: balance, content: content)
        }
        state.life.family.stageSinceDay = min(state.life.family.stageSinceDay, max(0, state.day - days))
        state.life.family.affection = 72
        state.life.family.lastPartnerDay = state.day
    }

    private static func hire(_ state: inout GameState, balance: BalanceConfig) -> [GameEvent] {
        if state.headcount >= balance.office(state.company.officeTier).headcountCap,
           let index = state.employees.lastIndex(where: { !$0.isFounder }) {
            state.employees.remove(at: index)
        }
        return RelationshipSystem.hirePartner(state: &state, balance: balance)
    }

    /// Puts the partner's anniversary in the diary on `day`, whatever the
    /// calendar's spacing would have said.
    private static func putAnniversary(on day: Int, _ state: inout GameState) {
        state.narrative.scheduled.removeAll { $0.eventID == FamilyCalendar.anniversaryEventID }
        NarrativeSystem.schedule(FamilyCalendar.anniversaryEventID, source: .life, day: day, state: &state)
    }
}
#endif

// MARK: end K7
