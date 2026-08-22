import Testing
import TycoonEngine

@MainActor
@Suite("GameEngine")
struct GameEngineTests {
    @Test func initStoresStateAndBalance() {
        let balance = TestBalance.standard
        let state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        let engine = GameEngine(state: state, balance: balance, content: TestContent.bundled)

        #expect(engine.state == state)
        #expect(engine.balance == balance)
        #expect(engine.state.speed == .paused)
    }

    @Test func weeklyBurnIsOperatingCostPlusRent() {
        let garage = TestBalance.make(weeklyOperatingCost: 400, garageRent: 0)
        let garageEngine = GameEngine(
            state: .newGame(companyName: "Acme", seed: 1, balance: garage),
            balance: garage,
            content: TestContent.bundled
        )
        #expect(garageEngine.weeklyBurn == 400)

        let rented = TestBalance.make(weeklyOperatingCost: 400, garageRent: 150)
        let rentedEngine = GameEngine(
            state: .newGame(companyName: "Acme", seed: 1, balance: rented),
            balance: rented,
            content: TestContent.bundled
        )
        #expect(rentedEngine.weeklyBurn == 550)
    }

    @Test func weeklyBurnIncludesTheFounderSalary() {
        let balance = TestBalance.make(weeklyOperatingCost: 400, garageRent: 0)
        let engine = GameEngine(
            state: .newGame(companyName: "Acme", seed: 1, balance: balance),
            balance: balance,
            content: TestContent.bundled
        )
        #expect(engine.weeklyBurn == 400)
        engine.send(.setFounderSalary(500))
        #expect(engine.weeklyBurn == 900)
    }

    @Test func setSpeedUpdatesState() {
        let balance = TestBalance.standard
        let engine = GameEngine(
            state: .newGame(companyName: "Acme", seed: 1, balance: balance),
            balance: balance,
            content: TestContent.bundled
        )

        engine.setSpeed(.x4)
        #expect(engine.state.speed == .x4)
        engine.setSpeed(.paused)
        #expect(engine.state.speed == .paused)
    }

    @Test func backgroundPauseRemembersAndRestoresSpeed() {
        let balance = TestBalance.standard
        let engine = GameEngine(
            state: .newGame(companyName: "Acme", seed: 1, balance: balance),
            balance: balance,
            content: TestContent.bundled
        )

        engine.setSpeed(.x2)
        engine.pauseForBackground()
        #expect(engine.state.speed == .paused)
        engine.resumeAfterForeground()
        #expect(engine.state.speed == .x2)

        // A game paused by the player stays paused across background/foreground.
        engine.setSpeed(.paused)
        engine.pauseForBackground()
        engine.resumeAfterForeground()
        #expect(engine.state.speed == .paused)

        engine.setSpeed(.paused)
    }

    @Test func newGameFactoryUsesBundledBalance() throws {
        let engine = GameEngine.newGame(companyName: "Bundled Co", seed: 42)
        let bundled = try BalanceConfig.loadBundled()

        #expect(engine.balance == bundled)
        #expect(engine.state.company.name == "Bundled Co")
        #expect(engine.state.company.cash == bundled.startingCash)
        #expect(engine.state.day == 0)
        #expect(engine.state.speed == .paused)
    }
}
