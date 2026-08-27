import SwiftUI
import TycoonContent
import TycoonEngine

/// Maps a pending narrative choice onto the app's `DecisionPrompt`, so
/// story beats use the same pause-and-choose sheet as poaches, buyouts and
/// staff moments.
///
/// Scaffold behavior: returns `nil` — there is no pending choice in state
/// yet — and `DecisionPrompt.pending` already consults it after the three
/// existing prompts, so WS-B lands the narrative sheet without touching
/// `DecisionSheet.swift` or any other App file.
enum NarrativeChoicePresenter {
    static func prompt(
        for state: GameState,
        content: ContentCatalog,
        balance: BalanceConfig
    ) -> DecisionPrompt? {
        nil
    }
}
