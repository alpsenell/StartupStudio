import Foundation

/// City districts the office can sit in. The district is an axis orthogonal
/// to `OfficeTier`: tier is the building's size, district is where it
/// stands — its cost multipliers and perks (see `BalanceConfig.CityBalance`).
public enum DistrictID: String, Codable, Equatable, Sendable, CaseIterable {
    case oldTown, suburbs, midtown, techPark, downtown

    public var displayName: String {
        switch self {
        case .oldTown: "Old Town"
        case .suburbs: "Suburbs"
        case .midtown: "Midtown"
        case .techPark: "Tech Park"
        case .downtown: "Downtown"
        }
    }
}

/// Whether the current office space is rented or owned outright.
public enum OfficeOwnership: Codable, Equatable, Sendable {
    case renting
    case owned(purchasePrice: Int)

    public var isOwned: Bool {
        if case .owned = self { return true }
        return false
    }
}

/// Where (and on what terms) the company offices, advanced by `CitySystem`.
public struct CityState: Codable, Equatable, Sendable {
    public var district: DistrictID
    public var ownership: OfficeOwnership
    /// Current market value of the owned space; 0 while renting. Drifts
    /// monthly while owned and is what a sale returns.
    public var propertyValue: Int

    public init(district: DistrictID, ownership: OfficeOwnership, propertyValue: Int) {
        self.district = district
        self.ownership = ownership
        self.propertyValue = propertyValue
    }

    /// Pre-city saves office in Old Town (rent multiplier 1.0), renting —
    /// exactly the old economics.
    public static let legacy = CityState(district: .oldTown, ownership: .renting, propertyValue: 0)
}

extension Rival {
    /// The district a rival's HQ sits in, derived deterministically from
    /// its appearance seed (also backfills rivals founded before the city
    /// existed).
    public var homeDistrict: DistrictID {
        if let raw = hqDistrict, let district = DistrictID(rawValue: raw) {
            return district
        }
        let all = DistrictID.allCases
        return all[Int(appearanceSeed % UInt64(all.count))]
    }
}
