import Foundation

// MARK: T3 (people)

/// Iteration 17 — T3 (J5). The lesson's price. S1's seating preview printed
/// the skill a mentor teaches and nothing the skill does; the engine
/// already charges for it twice — `fairWeeklyPay` reads `skills.total`, so
/// the student is owed more, and `RivalSystem.poachTarget` scores
/// `poachSkillWeight × skills.total`, so the student climbs the recruiters'
/// list. This file prints both, a quarter out, and says when the lesson
/// carries somebody past their rung (which is when they ask for the title:
/// `SeatingSystem.teach` → `SocialSystem.lessonAsksForPromotion`).
///
/// Pure reads, no draws. Nothing here runs while no seat is set.
extension GameState {
    /// Weeks the printed forecast looks ahead: a quarter.
    static let lessonForecastWeeks = 13

    /// The student after `weeks` of this mentor's weekly lesson, by the
    /// same arithmetic as `SeatingSystem.teach` (the mentor's own skill is
    /// the ceiling, the lesson shrinks as the gap closes).
    static func lessonForecast(
        mentor: Employee, student: Employee, skill: TrainableSkill, weeks: Int, balance: BalanceConfig
    ) -> Employee {
        var taught = student
        let ceiling = seatingSkill(skill, of: mentor)
        for _ in 0..<max(0, weeks) {
            let gain = seatingWeeklyLesson(mentor: mentor, student: taught, balance: balance)
            switch skill {
            case .coding: taught.skills.coding = min(ceiling, max(taught.skills.coding, taught.skills.coding + gain))
            case .design: taught.skills.design = min(ceiling, max(taught.skills.design, taught.skills.design + gain))
            case .marketing: taught.skills.marketing = min(ceiling, max(taught.skills.marketing, taught.skills.marketing + gain))
            }
        }
        return taught
    }

    /// Whether one week's lesson carried `after` past the bar of the rung
    /// above their title, having been at or under it before.
    static func lessonCrossesRung(before: Employee, after: Employee) -> Bool {
        guard after.level.next != nil else { return false }
        return SeniorityLevel.forSkillTotal(before.skills.total).rank <= before.level.rank
            && SeniorityLevel.forSkillTotal(after.skills.total).rank > after.level.rank
    }

    /// J5's gate on `promotionDemand`: somebody with a seat in the map whose
    /// skills read a rung above their title. False for everyone while no
    /// seat is set.
    func lessonOutgrewLevel(_ employee: Employee) -> Bool {
        guard seatingIsSet, !employee.isFounder, employee.level.next != nil,
              company.seating[employee.id] != nil
        else { return false }
        return SeniorityLevel.forSkillTotal(employee.skills.total).rank > employee.level.rank
    }

    /// The score `RivalSystem.poachTarget` gives `employee`, term for term.
    /// Kept beside the preview that prints it; if the poach score gains a
    /// term, add it here too.
    func lessonPoachScore(_ employee: Employee, balance: BalanceConfig) -> Double {
        let config = balance.rivals
        let fairPay = balance.fairWeeklyPay(for: employee)
        let underpaid = fairPay > 0 ? max(0, (fairPay - Double(employee.weeklySalary)) / fairPay) : 0
        let lowMorale = max(0, (70 - employee.morale) / 70)
        return config.poachSkillWeight * employee.skills.total
            + config.poachUnderpaidWeight * underpaid
            + config.poachMoraleWeight * lowMorale
            + ladderPoachScoreDelta(employee, fairPay: fairPay, underpaidWeight: config.poachUnderpaidWeight, balance: balance)
            + (employee.id == seatingDoorOccupantID() ? balance.seating.doorPoachWeight : 0)
    }

    /// 1-based place of `employee` on the recruiters' list (1 = the one a
    /// rival calls first), with `employee` standing in for their row.
    func lessonRecruiterRank(_ employee: Employee, balance: BalanceConfig) -> Int {
        let scored = employees
            .filter { !$0.isFounder }
            .map { person -> (Double, String) in
                let row = person.id == employee.id ? employee : person
                return (lessonPoachScore(row, balance: balance), row.id.uuidString)
            }
            .sorted { $0.0 != $1.0 ? $0.0 > $1.0 : $0.1 > $1.1 }
        return (scored.firstIndex { $0.1 == employee.id.uuidString } ?? scored.count) + 1
    }

    /// The lines under "X teaches Y …": the quarter's fair pay, the
    /// recruiters' list, and the rung.
    func lessonPriceLines(
        mentor: Employee, student: Employee, skill: TrainableSkill, balance: BalanceConfig
    ) -> [SeatingLine] {
        let taught = Self.lessonForecast(
            mentor: mentor, student: student, skill: skill, weeks: Self.lessonForecastWeeks, balance: balance
        )
        let name = seatingFirstName(student.id)
        var lines: [SeatingLine] = []
        let pay = Int((balance.fairWeeklyPay(for: taught) - balance.fairWeeklyPay(for: student)).rounded())
        if pay >= 1 {
            lines.append(SeatingLine("\(name)'s fair pay +\(pay.dollars) a week by the quarter's end, and rising.", tone: .bad))
        }
        let rankNow = lessonRecruiterRank(student, balance: balance)
        let rankThen = lessonRecruiterRank(taught, balance: balance)
        if rankThen < rankNow {
            lines.append(SeatingLine("\(name) climbs the recruiters' list: \(Self.lessonOrdinal(rankNow)) → \(Self.lessonOrdinal(rankThen)).", tone: .bad))
        } else if pay >= 1 {
            lines.append(SeatingLine("\(name) stays \(Self.lessonOrdinal(rankNow)) on the recruiters' list.", tone: .plain))
        }
        if let next = student.level.next,
           SeniorityLevel.forSkillTotal(taught.skills.total).rank > student.level.rank,
           SeniorityLevel.forSkillTotal(student.skills.total).rank <= student.level.rank {
            lines.append(SeatingLine("By then \(name) reads as \(next.displayName.lowercased()): expect them to ask for the title.", tone: .bad))
        }
        return lines
    }

    static func lessonOrdinal(_ n: Int) -> String {
        let suffix: String
        switch (n % 10, n % 100) {
        case (_, 11...13): suffix = "th"
        case (1, _): suffix = "st"
        case (2, _): suffix = "nd"
        case (3, _): suffix = "rd"
        default: suffix = "th"
        }
        return "\(n)\(suffix)"
    }
}

// MARK: end T3
