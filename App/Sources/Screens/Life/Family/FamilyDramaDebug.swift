import Foundation
import TycoonEngine

/// Iteration 11, wave two — W2. The screenshot pass's one flag.
///
/// `-autoFamily <stage>`: `room`, `affair`, `discovered`, `ask`, `funeral`
/// or `custody`. Everything it does goes through the reducer, so a picture
/// taken this way is a picture of the real thing.
enum FamilyDramaDebug {
    static let stages = [
        "room", "affair", "discovered", "table", "will", "ask", "funeral", "custody",
    ]

    @MainActor private static var took = false

    @MainActor
    static var requestedStage: String? {
        #if DEBUG
        guard let word = DebugLaunch.value(after: "-autoFamily")?.lowercased(),
              stages.contains(word)
        else { return nil }
        return word
        #else
        return nil
        #endif
    }

    /// Applied once per launch, on whatever save is loaded.
    @MainActor
    static func setUpIfAsked(engine: GameEngine) {
        #if DEBUG
        guard !took, let stage = requestedStage else { return }
        took = true
        engine.send(.seedFamilyDrama(stage: stage))
        #endif
    }

    /// Which sheet the pass wants open over the room, if any. The room
    /// arms it once, the same way `-autoRoute courtroom` arms the hearing.
    @MainActor
    static var armedSheet: String? {
        switch requestedStage {
        case "discovered": "confrontation"
        case "funeral": "funeral"
        case "will": "will"
        default: nil
        }
    }
}
