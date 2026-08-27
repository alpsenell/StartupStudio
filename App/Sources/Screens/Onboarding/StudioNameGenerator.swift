import Foundation
import TycoonContent

/// Suggests company names and founder names for the new-game flow.
///
/// Deterministic for a given seed so the "shuffle" button walks a stable
/// list rather than re-rolling the system RNG — the flow runs before the
/// engine exists, so this is the one place in the app that owns its own
/// tiny generator.
enum StudioNameGenerator {
    /// Left halves: short, concrete, pronounceable.
    private static let prefixes = [
        "Lumen", "Parallax", "Hexbyte", "Northgate", "Cobalt", "Tinder", "Foxglove",
        "Ampere", "Cinder", "Basalt", "Halcyon", "Juniper", "Kestrel", "Meridian",
        "Nimbus", "Orbit", "Quill", "Raster", "Solder", "Tessellate", "Umber",
        "Vellum", "Wren", "Zephyr", "Anvil", "Bramble", "Cardinal", "Driftwood",
    ]

    /// Right halves: the studio-suffix vocabulary of small software shops.
    private static let suffixes = [
        "Labs", "Works", "Studio", "Systems", "Collective", "Foundry", "Softworks",
        "Industries", "Digital", "Machines", "Union", "Craft", "Kernel", "Interactive",
    ]

    /// Single-word names that need no suffix.
    private static let solos = [
        "Overcast", "Sidecar", "Paperclip", "Longhand", "Undertone", "Firstlight",
        "Backchannel", "Rooftop", "Nightshift", "Bytecraft", "Handmade", "Slowburn",
    ]

    /// The `index`-th suggested company name. Wraps, so a shuffle button
    /// can just increment forever.
    static func companyName(index: Int) -> String {
        let cycle = index % (prefixes.count + solos.count)
        if cycle < solos.count {
            return solos[cycle]
        }
        let offset = cycle - solos.count
        return "\(prefixes[offset % prefixes.count]) \(suffixes[(index / 3) % suffixes.count])"
    }

    /// The `index`-th suggested founder name, drawn from the content
    /// catalog's people pools so the founder sounds like the rest of the
    /// cast. Falls back to a small built-in pool if the catalog is empty.
    static func founderName(index: Int, names: NamePools) -> String {
        let firsts = names.firstNames.isEmpty ? fallbackFirstNames : names.firstNames
        let lasts = names.lastNames.isEmpty ? fallbackLastNames : names.lastNames
        return "\(firsts[index % firsts.count]) \(lasts[(index / 3 + 1) % lasts.count])"
    }

    private static let fallbackFirstNames = ["Ada", "Kai", "Mira", "Tomas", "Priya", "Noor"]
    private static let fallbackLastNames = ["Okafor", "Lindqvist", "Reyes", "Bhatt", "Novak", "Weaver"]
}
