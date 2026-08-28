import Foundation
import Testing
import TycoonContent
import TycoonEngine

/// An economy with the two founder→room hooks switched on.
private func hookedEconomy(
    founderMoodMoraleFloor: Double = 50,
    founderMoodMoraleFactor: Double = 0.12,
    paceMismatchMoralePenalty: Double = 6
) -> BalanceConfig.EconomyBalance {
    var economy = TestBalance.neutralEconomy
    economy.founderMoodMoraleFloor = founderMoodMoraleFloor
    economy.founderMoodMoraleFactor = founderMoodMoraleFactor
    economy.paceMismatchMoralePenalty = paceMismatchMoralePenalty
    return economy
}

private func balance(
    economy: BalanceConfig.EconomyBalance = hookedEconomy(),
    staff: BalanceConfig.StaffBalance = .standard
) -> BalanceConfig {
    TestBalance.make(
        candidateRefreshDays: 10_000,
        contractOfferRefreshDays: 10_000,
        eventCheckIntervalDays: 10_000,
        life: TestBalance.quietLife,
        staff: staff,
        economy: economy
    )
}

/// A studio with one hire, the founder's meters pinned, and the day
/// mid-week so nothing settles under the assertions.
private func studio(_ balance: BalanceConfig, mood: Double = 70) -> GameState {
    var state = GameState.newGame(companyName: "Acme", seed: 9, balance: balance)
    TestLife.pinPeak(&state)
    state.life.meters.mood = mood
    state.employees.append(TestPeople.employee())
    state.day = 2
    return state
}

/// Where the roster's morale settles after enough days for the drift to
/// converge — the number these hooks actually move.
private func settledMorale(_ state: GameState, _ balance: BalanceConfig, days: Int = 60) -> Double {
    var state = state
    let content = TestContent.tiny()
    for _ in 0..<days { Reducer.tick(&state, balance: balance, content: content) }
    return state.employees.last?.morale ?? 0
}

@Suite("The founder in the room")
struct FounderInTheRoomTests {
    @Test("A founder in a bad way drags the room down")
    func miserableFounderCostsMorale() {
        let config = balance()
        let fine = settledMorale(studio(config, mood: 80), config)
        let struggling = settledMorale(studio(config, mood: 5), config)
        #expect(struggling < fine)
    }

    @Test("A cheerful founder is worth nothing extra — the hook only ever costs")
    func goodMoodIsNotABuff() {
        let config = balance()
        // Anything at or above the floor reads the same, so a founder who
        // spends every evening on their own mood cannot buy the room's.
        #expect(settledMorale(studio(config, mood: 100), config)
            == settledMorale(studio(config, mood: 50), config))
    }

    @Test("During a team crunch, the founder's own schedule is a company decision")
    func crunchMismatchCostsMorale() {
        let config = balance()
        func morale(_ schedule: WorkSchedule) -> Double {
            var state = studio(config)
            state.economy.workPace = .crunch
            state.life.schedule = schedule
            return settledMorale(state, config)
        }

        let alongside = morale(.crunch)
        let middling = morale(.normal)
        let deckchair = morale(.chill)
        #expect(alongside > middling)
        #expect(middling > deckchair)
    }

    @Test("A relaxed company does not care what hours the founder keeps")
    func noMismatchPenaltyOffCrunch() {
        let config = balance()
        func morale(_ schedule: WorkSchedule) -> Double {
            var state = studio(config)
            state.life.schedule = schedule
            return settledMorale(state, config)
        }
        #expect(morale(.chill) == morale(.crunch))
    }

    @Test("A founder who is away is not judged on their schedule")
    func awayFounderIsExempt() {
        let config = balance()
        var away = studio(config)
        away.economy.workPace = .crunch
        away.life.schedule = .chill
        away.life.awayUntilDay = away.day + 400
        away.life.awaySinceDay = away.day
        away.life.awayReason = "Hospital"

        var present = away
        present.life.awayUntilDay = nil
        present.life.awaySinceDay = nil
        present.life.awayReason = nil

        // The absence has its own penalty; the mismatch must not stack a
        // second one on a founder who is in hospital.
        #expect(
            away.founderMoraleImpact(balance: config)
                > present.founderMoraleImpact(balance: config)
        )
    }

    @Test("A signed-off founder counts as crunching with nobody, not as slacking")
    func convalescingReadsAsChill() {
        let config = balance()
        var state = studio(config)
        state.economy.workPace = .crunch
        state.life.schedule = .crunch
        state.economy.convalescingUntilDay = state.day + 14

        // `effectiveSchedule` reads chill while signed off, so the room
        // does notice — which is right: the founder genuinely isn't there.
        #expect(state.founderMoraleImpact(balance: config) < 0)
    }

    @Test("An economy without the hooks is the simulation that shipped before them")
    func inertWithoutTheHooks() {
        let config = balance(economy: TestBalance.neutralEconomy)
        var crunching = studio(config, mood: 0)
        crunching.economy.workPace = .crunch
        crunching.life.schedule = .chill

        #expect(crunching.founderMoraleImpact(balance: config) == 0)
    }
}
