import Foundation

/// The two story screens HQ pushes: the week's front page and the run's
/// timeline. HQ registers a `navigationDestination` for this, so the
/// journal card, the chapter card and the router all push the same way.
enum StoryDestination: Hashable {
    case newspaper
    case timeline
}
