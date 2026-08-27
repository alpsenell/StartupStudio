/// The player's chosen difficulty. Picked once at `newGame` and recorded in
/// `GameState.difficulty`; `GameEngine` rescales the bundled balance with
/// `BalanceConfig.adjusted(for:)` once at creation/resume. Difficulty only
/// rescales constants — it never touches the RNG draw order, so a seed
/// walks the same random path on every setting.
public enum Difficulty: String, Codable, Equatable, Sendable, CaseIterable {
    case easy, normal, hard

    public var displayName: String {
        switch self {
        case .easy: "Easy"
        case .normal: "Normal"
        case .hard: "Hard"
        }
    }

    /// One-line pitch for the difficulty picker.
    public var blurb: String {
        switch self {
        case .easy: "Deeper pockets, cheaper rent, and forgiving critics."
        case .normal: "The intended challenge: every hire and launch has to earn its keep."
        case .hard: "Thin runway, pricey talent, and a press that expects greatness."
        }
    }
}
