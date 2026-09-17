import SwiftUI
import TycoonEngine

// MARK: X4 (the launch party)

/// Iteration 18 — X4. The party in words and colours: the line under each
/// venue, the paragraph the morning after, the venue's backdrop, and the
/// snark the paper files when the room was bigger than the reviews earned.
enum PartyCopy {
    /// "Everyone +4 morale · hype +8 · four on the list" — what the venue
    /// buys, before its price. The desperate version says so first, because
    /// it is the thing the player is about to do wrong.
    static func effectLine(_ quote: PartyQuote) -> String {
        let morale = "Everyone +\(Int(quote.morale.rounded())) morale"
        let hype: String = if quote.hype > 0.5 {
            "hype +\(Int(quote.hype.rounded()))"
        } else if quote.hype < -0.5 {
            "hype −\(Int(abs(quote.hype).rounded()))"
        } else {
            "no hype at all"
        }
        let list = "\(quote.guestLimit) on the list"
        guard quote.desperate else { return "\(morale) · \(hype) · \(list)" }
        return "Reads desperate at \(quote.reviewScore) · \(morale) · \(hype) · every outlet colder"
    }

    /// The paragraph on the sheet the morning after.
    static func aftermath(_ party: LaunchParty, product: Product) -> String {
        let where_ = party.venue.displayName.lowercased()
        let heads = party.guests.count
        let came = heads == 0
            ? "Nobody outside the company came, which nobody minded."
            : "\(heads) \(heads == 1 ? "name" : "names") from outside the company came."
        guard party.desperate else {
            return "\(product.name) launched at \(party.reviewScore), and you took the room to \(where_). "
                + "\(came) The photographs are good."
        }
        return "\(product.name) launched at \(party.reviewScore), and you took the room to \(where_) anyway. "
            + "\(came) Everybody was very kind about it, which is the part that stings."
    }

    /// What the paper files. `nil` on a party that was earned — the front
    /// page has better things to lead with than a company enjoying itself.
    static func newspaperLine(_ party: LaunchParty, product: Product) -> String? {
        guard party.desperate else { return nil }
        switch party.venue {
        case .rooftop:
            return "\(product.name) scored \(party.reviewScore). There was a photographer on the roof."
        case .bar:
            return "\(product.name) scored \(party.reviewScore). The bar was open regardless."
        case .office:
            return nil
        }
    }

    /// A two-stop gradient per venue, the networking floor's device: enough
    /// to tell the rooms apart without asking PixelKit for new backdrops.
    static func backdrop(_ venue: PartyVenue) -> [Color] {
        switch venue {
        case .office: [Color(red: 0.14, green: 0.17, blue: 0.24), Color(red: 0.30, green: 0.34, blue: 0.42)]
        case .bar: [Color(red: 0.24, green: 0.15, blue: 0.12), Color(red: 0.46, green: 0.30, blue: 0.20)]
        case .rooftop: [Color(red: 0.18, green: 0.12, blue: 0.34), Color(red: 0.56, green: 0.28, blue: 0.40)]
        }
    }

    /// What fits on a tag over somebody's head. A first name for a person;
    /// for an outlet, the word that identifies it — "The Stack Review" is
    /// "Stack", not "The", which is what taking the first word gave.
    static func shortName(_ name: String) -> String {
        var words = name.split(separator: " ").map(String.init)
        if words.count > 1, words[0].caseInsensitiveCompare("the") == .orderedSame {
            words.removeFirst()
        }
        return words.first ?? name
    }

    /// A stable seed from a name, so an outlet's reporter has the same face
    /// at every party the studio ever throws.
    static func seed(for name: String) -> UInt64 {
        name.utf8.reduce(UInt64(0)) { $0 &* 31 &+ UInt64($1) }
    }

    /// A stable identity for somebody who is not in any table — a review
    /// outlet's reporter. The figures are keyed on it, and a fresh `UUID()`
    /// every render would restart every sprite in the room.
    static func id(for name: String) -> UUID {
        var bytes = [UInt8](repeating: 0, count: 16)
        var hash = seed(for: name)
        for index in 0..<16 {
            hash = hash &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            bytes[index] = UInt8(truncatingIfNeeded: hash >> 33)
        }
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}

// MARK: end X4

// MARK: X4 (the launch party) — the journal and the paper

extension EventCopy {
    /// The journal line, and the one the paper picks up. An earned party is
    /// a company enjoying itself; a party the reviews did not pay for is the
    /// paper's kind of story, and the line says so without editorialising —
    /// it just puts the score next to the venue and lets the reader do it.
    static func partyLine(
        product: Product?,
        venue: String,
        cost: Int,
        guests: Int,
        desperate: Bool
    ) -> String {
        let name = product?.name ?? String(
            localized: "The launch", comment: "Launch party line: a product whose name is gone"
        )
        let where_ = PartyVenue(rawValue: venue)?.displayName.lowercased() ?? venue
        let came = guests == 0 ? "" : " \(guests) from outside came."
        guard desperate else {
            return "A launch party for \(name) at \(where_), for \(cost.money).\(came)"
        }
        let score = score(of: product)
        return "A launch party for \(name) at \(where_), for \(cost.money)"
            + (score > 0 ? ", on a \(score)." : ".")
            + came
            + " The press standing cooled for it."
    }

    private static func score(of product: Product?) -> Int {
        guard let product, case .released(let info) = product.stage else { return 0 }
        return info.averageReviewScore
    }
}

// MARK: end X4
