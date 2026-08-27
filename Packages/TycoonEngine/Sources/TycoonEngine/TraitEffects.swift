import TycoonContent

/// The single seam between employee traits (WS-F) and the systems that
/// consume them (WS-A's `EmployeeSystem`, WS-F's `RivalSystem`).
///
/// Every entry point is an identity stub in the scaffold — the factors
/// return 1, the deltas return 0 — so today's numbers are untouched and the
/// call sites already exist where WS-F needs them. WS-F fills these in from
/// `content.traits`; nobody else edits this file, and no other file needs to
/// change when trait effects land.
public enum TraitEffects {
    /// Multiplies an employee's daily product/contract output.
    public static func outputFactor(_ employee: Employee, content: ContentCatalog) -> Double {
        1
    }

    /// Multiplies an employee's daily skill growth rate (the `mentor`
    /// trait lifts their teammates through this hook).
    public static func growthFactor(_ employee: Employee, content: ContentCatalog) -> Double {
        1
    }

    /// Shifts an employee's daily morale target.
    public static func moraleTargetDelta(_ employee: Employee, content: ContentCatalog) -> Double {
        0
    }

    /// Extra days of low morale an employee tolerates before resigning.
    public static func quitStreakBonus(_ employee: Employee, content: ContentCatalog) -> Int {
        0
    }

    /// Multiplies an employee's resistance to a rival's poach attempt
    /// (> 1 makes them harder to poach).
    public static func poachResistance(_ employee: Employee, content: ContentCatalog) -> Double {
        1
    }
}
