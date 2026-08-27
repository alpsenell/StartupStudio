import TycoonContent

/// The single seam between employee traits and the systems that consume
/// them (`EmployeeSystem`'s daily output, growth, morale and quit sweep,
/// `RivalSystem`'s poaching, and WS-F's own `TraitSystem`).
///
/// Also the home of the derivation itself: an employee's traits are a pure
/// function of their `appearanceSeed`, so the same face always has the same
/// personality, no RNG stream is consumed, and a save written before traits
/// existed backfills identically every time it is loaded.
///
/// Every entry point takes only `(Employee, ContentCatalog)` — the
/// signatures are fixed by the scaffold and shared with WS-A's call sites,
/// so the per-employee clamps live here as constants rather than in the
/// balance. The dials that reach the whole roster are in
/// `BalanceConfig.TraitBalance`, where `TraitSystem` can read them.
public enum TraitEffects {
    // MARK: - Derivation

    /// The 14 traits, in the order `Traits.json` lists them.
    ///
    /// Duplicated here (rather than read from the catalog) on purpose:
    /// `Employee.init` backfills traits during `Codable` decoding, where
    /// there is no catalog to consult, and the derivation has to be
    /// identical whatever the content bundle. `TraitContentTests` in
    /// TycoonContent pins `Traits.json` to this exact list and order.
    public static let canonicalTraitIDs: [String] = [
        "nightOwl", "mentor", "perfectionist", "speedster", "socialButterfly",
        "loner", "flightRisk", "loyalist", "jokester", "grumbler",
        "prodigy", "workhorse", "fragile", "showman",
    ]

    /// How many traits one employee carries.
    public static let traitsPerEmployee = 2

    /// The two traits belonging to an appearance seed.
    ///
    /// `CharacterAppearance` consumes the first four SplitMix64 words of
    /// the seed (skin, hair style, hair color, shirt); the traits take
    /// words five and six, so every look that already exists keeps it and
    /// adding traits shifted nothing. The second draw picks out of the
    /// remaining ids, so an employee never carries the same trait twice.
    public static func derivedTraitIDs(appearanceSeed: UInt64) -> [String] {
        let pool = canonicalTraitIDs
        guard pool.count > traitsPerEmployee else { return pool }

        var rng = SeededRNG(seed: appearanceSeed)
        for _ in 0..<4 { _ = rng.next() }  // the appearance's four words

        var remaining = pool
        var picked: [String] = []
        for _ in 0..<traitsPerEmployee {
            let index = Int(rng.next() % UInt64(remaining.count))
            picked.append(remaining.remove(at: index))
        }
        return picked
    }

    /// The catalog entries for an employee's traits, in the employee's own
    /// order. Ids the catalog doesn't know are skipped.
    public static func definitions(
        for employee: Employee,
        content: ContentCatalog
    ) -> [TraitDef] {
        employee.traits.compactMap { id in content.traits.first { $0.id == id } }
    }

    /// The combined effects of an employee's traits: multipliers multiply,
    /// deltas add. An employee with no traits, or with ids the catalog
    /// doesn't know, gets exactly the neutral set — which is why a content
    /// bundle without `Traits.json` changes nothing.
    static func combined(
        _ employee: Employee,
        content: ContentCatalog
    ) -> TraitDef.Effects {
        var result = TraitDef.Effects.neutral
        for def in definitions(for: employee, content: content) {
            let effects = def.effects
            result.outputMult *= effects.outputMult
            result.skillGrowthMult *= effects.skillGrowthMult
            result.moraleTargetDelta += effects.moraleTargetDelta
            result.quitStreakBonus += effects.quitStreakBonus
            result.poachResist *= effects.poachResist
            result.teamGrowthBonus += effects.teamGrowthBonus
            result.teamMoraleBonus += effects.teamMoraleBonus
            result.dailyReputationBonus += effects.dailyReputationBonus
        }
        return result
    }

    // MARK: - Clamps

    /// Bounds on what a *pair* of traits may do to one person, so an
    /// unlucky (or very lucky) roll can never produce an absurd employee.
    /// Constants rather than balance keys because the hook signatures the
    /// scaffold fixed carry no `BalanceConfig`.
    enum Limits {
        static let outputMultMin = 0.70
        static let outputMultMax = 1.45
        static let growthMultMin = 0.60
        static let growthMultMax = 1.90
        static let moraleDelta = 12.0
        static let quitStreakBonus = 12
        static let poachResistMin = 0.40
        static let poachResistMax = 3.00
    }

    // MARK: - Hooks

    /// Multiplies an employee's daily product/contract output.
    public static func outputFactor(_ employee: Employee, content: ContentCatalog) -> Double {
        clamp(
            combined(employee, content: content).outputMult,
            min: Limits.outputMultMin, max: Limits.outputMultMax
        )
    }

    /// Multiplies an employee's daily skill growth rate. This is their own
    /// appetite for learning; the `mentor` trait lifts everyone *else*
    /// through `TraitSystem`, which can see the whole roster.
    public static func growthFactor(_ employee: Employee, content: ContentCatalog) -> Double {
        clamp(
            combined(employee, content: content).skillGrowthMult,
            min: Limits.growthMultMin, max: Limits.growthMultMax
        )
    }

    /// Shifts an employee's daily morale target.
    public static func moraleTargetDelta(_ employee: Employee, content: ContentCatalog) -> Double {
        clamp(
            combined(employee, content: content).moraleTargetDelta,
            min: -Limits.moraleDelta, max: Limits.moraleDelta
        )
    }

    /// Extra days of low morale an employee tolerates before resigning
    /// (negative for the ones who never had much patience).
    public static func quitStreakBonus(_ employee: Employee, content: ContentCatalog) -> Int {
        let raw = combined(employee, content: content).quitStreakBonus
        return min(Limits.quitStreakBonus, max(-Limits.quitStreakBonus, raw))
    }

    /// Multiplies an employee's resistance to a rival's poach attempt
    /// (> 1 makes them harder to poach).
    public static func poachResistance(_ employee: Employee, content: ContentCatalog) -> Double {
        clamp(
            combined(employee, content: content).poachResist,
            min: Limits.poachResistMin, max: Limits.poachResistMax
        )
    }

    // MARK: - Roster-wide effects (read by `TraitSystem`)

    /// How much faster everyone else learns thanks to the mentors on
    /// payroll, before the balance's strength and cap.
    static func rawTeamGrowthBonus(_ employee: Employee, content: ContentCatalog) -> Double {
        combined(employee, content: content).teamGrowthBonus
    }

    /// This person's daily contribution to the room's mood.
    static func rawTeamMoraleBonus(_ employee: Employee, content: ContentCatalog) -> Double {
        combined(employee, content: content).teamMoraleBonus
    }

    /// This person's daily contribution to the company's name in the press.
    static func rawReputationBonus(_ employee: Employee, content: ContentCatalog) -> Double {
        combined(employee, content: content).dailyReputationBonus
    }

    // MARK: - Presentation

    /// One line per trait explaining what it is doing to this employee,
    /// for the manage sheet. Empty when the catalog has no traits.
    public static func explanations(
        for employee: Employee,
        content: ContentCatalog
    ) -> [(name: String, detail: String)] {
        definitions(for: employee, content: content).map { def in
            (def.name, def.blurb ?? Self.describe(def.effects))
        }
    }

    /// A plain-numbers summary of an effects block, used when a trait
    /// ships without a blurb.
    public static func describe(_ effects: TraitDef.Effects) -> String {
        var parts: [String] = []
        if effects.outputMult != 1 {
            parts.append("output \(percent(effects.outputMult))")
        }
        if effects.skillGrowthMult != 1 {
            parts.append("learning \(percent(effects.skillGrowthMult))")
        }
        if effects.moraleTargetDelta != 0 {
            parts.append("morale \(signed(effects.moraleTargetDelta))")
        }
        if effects.quitStreakBonus != 0 {
            parts.append("patience \(effects.quitStreakBonus > 0 ? "+" : "")\(effects.quitStreakBonus)d")
        }
        if effects.poachResist != 1 {
            parts.append("poach resistance \(percent(effects.poachResist))")
        }
        if effects.teamGrowthBonus != 0 {
            parts.append("teaches the team")
        }
        if effects.teamMoraleBonus != 0 {
            parts.append(effects.teamMoraleBonus > 0 ? "lifts the room" : "drains the room")
        }
        if effects.dailyReputationBonus != 0 {
            parts.append("gets you press")
        }
        return parts.isEmpty ? "No measurable effect." : parts.joined(separator: " · ")
    }

    private static func percent(_ multiplier: Double) -> String {
        let delta = (multiplier - 1) * 100
        return "\(delta > 0 ? "+" : "")\(Int(delta.rounded()))%"
    }

    private static func signed(_ value: Double) -> String {
        "\(value > 0 ? "+" : "")\(Int(value.rounded()))"
    }

    private static func clamp(_ value: Double, min lower: Double, max upper: Double) -> Double {
        Swift.min(upper, Swift.max(lower, value))
    }
}
