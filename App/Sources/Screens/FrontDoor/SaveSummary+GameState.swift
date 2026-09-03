import Foundation
import SwiftUI
import TycoonEngine
import TycoonSave

extension SaveSummary {
    /// What the front door says about a save, read off the state the
    /// autosave is about to write: the company, the founder and their
    /// face, the day, the chapter, and the ending if the run is over.
    init(state: GameState) {
        let founder = state.employees.first { $0.isFounder }
        self.init(
            companyName: state.company.name,
            founderName: state.progression.founder.name,
            day: state.day,
            ending: state.gameOver?.kind.rawValue,
            chapter: state.progression.chapter,
            chapterTitle: state.progression.chapterTitle,
            founderAppearanceSeed: founder?.appearanceSeed ?? state.progression.founder.appearanceSeed
        )
    }

    /// The ending the summary records, when the run is over.
    var endingKind: EndingKind? {
        ending.flatMap(EndingKind.init(rawValue:))
    }
}

extension GameSettings {
    private static let currentSlotKey = "settings.currentSlot"

    /// The slot the player last opened, so the next launch's Continue is
    /// the game they were in. Outside the simulation like every other
    /// setting: the save files are the truth, this is only which one.
    static var currentSlot: Int {
        get { UserDefaults.standard.integer(forKey: currentSlotKey) }
        set { UserDefaults.standard.set(newValue, forKey: currentSlotKey) }
    }
}

// MARK: - Environment

/// The session, for the one screen deep in the game that needs the front
/// door rather than the engine: the founder biography's "Start a new
/// company" goes back to the title screen and its slot picker.
///
/// Optional so a snapshot test can render that screen without standing
/// a session up; the biography keeps its own setup sheet as the fallback.
private struct GameSessionKey: EnvironmentKey {
    static let defaultValue: GameSession? = nil
}

extension EnvironmentValues {
    var gameSession: GameSession? {
        get { self[GameSessionKey.self] }
        set { self[GameSessionKey.self] = newValue }
    }
}
