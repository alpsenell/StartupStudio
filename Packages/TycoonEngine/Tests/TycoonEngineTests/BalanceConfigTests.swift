import Testing
import TycoonEngine

@Suite("BalanceConfig")
struct BalanceConfigTests {
    @Test func loadBundledDecodesAndGarageRentIsZero() throws {
        let balance = try BalanceConfig.loadBundled()
        #expect(balance.office(.garage).weeklyRent == 0)
        #expect(balance.startingCash > 0)
        #expect(balance.weeklyOperatingCost > 0)
        #expect(balance.bankruptcyGraceDays > 0)
        for tier in OfficeTier.allCases {
            #expect(balance.offices[tier.rawValue] != nil)
        }
        #expect(balance.eventCheckIntervalDays > 0)
        #expect(balance.eventChance >= 0)
        #expect(balance.eventChance <= 1)
    }

    @Test func loadBundledDecodesTheLifeBlock() throws {
        let balance = try BalanceConfig.loadBundled()
        let life = balance.life
        #expect(life.startingWallet == 2_000)
        // The founder pays themselves from day one: enough to cover the
        // studio flat's rent so the wallet does not drift negative by
        // default (WS-A's founder-consequences pass).
        #expect(life.defaultFounderSalary == 200)
        #expect(life.founderSalaryMax > 0)
        for schedule in WorkSchedule.allCases {
            #expect(life.drift[schedule.rawValue] != nil, Comment(rawValue: schedule.rawValue))
            #expect(life.scheduleOutputFactor[schedule.rawValue] != nil, Comment(rawValue: schedule.rawValue))
        }
        for activity in WeekendActivity.allCases {
            #expect(life.activities[activity.rawValue] != nil, Comment(rawValue: activity.rawValue))
        }
        for tier in HomeTier.allCases {
            #expect(life.homes[tier.rawValue] != nil, Comment(rawValue: tier.rawValue))
        }
        #expect(balance.home(.studioFlat).upgradeCost == 0)
        #expect(balance.home(.studioFlat).weeklyRent > 0)
        #expect(balance.home(.penthouse).moodBonus > balance.home(.house).moodBonus)
        #expect(HomeTier(rawValue: life.childMinHome) != nil)
        #expect(life.lifeEventIntervalDays > 0)
        #expect(life.lifeEventChance >= 0)
        #expect(life.lifeEventChance <= 1)
        #expect(life.coldOutputFactor > 0)
        #expect(life.coldOutputFactor < 1)
        #expect(life.burnoutEnergyThreshold < life.burnoutRecoveryEnergy)
        #expect(life.hospitalHealthThreshold < life.hospitalRecoveryHealth)
    }

    @Test func memberwiseInitializerAllowsCustomValues() {
        let balance = TestBalance.make(
            startingCash: 1,
            weeklyOperatingCost: 2,
            bankruptcyGraceDays: 3,
            garageRent: 4
        )
        #expect(balance.startingCash == 1)
        #expect(balance.weeklyOperatingCost == 2)
        #expect(balance.bankruptcyGraceDays == 3)
        #expect(balance.office(.garage).weeklyRent == 4)
        #expect(balance.office(.campus).headcountCap == 40)
    }
}
