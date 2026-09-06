import TycoonEngine

/// Iteration 7 (R5) — how the app names an ending a company kept running
/// past.
///
/// Two endings can be played past, and both of them are a state the
/// company is now permanently in rather than an event that happened to
/// it: it is *public*, or it is *yours*. The biography's extra line and
/// the front door's Continue card both say the same word, from here.
extension EndingKind {
    /// The word the epilogue line leads with: "**Public** since day 812".
    var epilogueNoun: String {
        switch self {
        case .ipo: "Public"
        case .independent: "Yours"
        // The other five cannot be continued (`Reducer` refuses them), so
        // this is only ever a fallback; the headline is the honest word.
        // Iteration 9 (L2): *Walked away* is deliberately among them —
        // the founder is not there any more.
        case .bankruptcy, .acquired, .oustedByBoard, .soldUp, .walkedAway: headline
        }
    }
}
