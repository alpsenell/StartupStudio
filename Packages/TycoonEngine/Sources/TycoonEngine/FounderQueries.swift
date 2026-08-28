import Foundation

/// The read-only questions the Life, Team and networking screens ask about
/// the founder's own life before they draw a button.
///
/// Every one of these answers "why is this greyed out?" with the *engine's*
/// reason, delegating to the same system that would refuse the action. The
/// alternative — SwiftUI re-deriving each gate — is the bug where a button
/// looks available and does nothing, and it is the bug this file exists to
/// make impossible.
extension GameState {
    /// Why a training session would be refused, or `nil` when it would go
    /// ahead.
    public func trainingBlocker(_ method: TrainingMethod, balance: BalanceConfig) -> String? {
        FounderSystem.trainingBlocker(method, state: self, balance: balance)
    }

    /// Why this networking deal cannot be made, or `nil` when it can.
    public func networkingOfferBlocker(
        _ offer: NetworkingOffer,
        contactID: UUID,
        balance: BalanceConfig
    ) -> String? {
        NetworkingSystem.offerBlocker(offer, contactID: contactID, state: self, balance: balance)
    }

    /// Why an evening with the founder's partner would be refused, or
    /// `nil`.
    public func partnerActivityBlocker(
        _ activity: PartnerActivity,
        balance: BalanceConfig
    ) -> String? {
        RelationshipSystem.partnerBlocker(activity, state: self, balance: balance)
    }

    /// Why a hang-out with somebody on the team would be refused, or `nil`.
    public func hangOutBlocker(employeeID: UUID, balance: BalanceConfig) -> String? {
        RelationshipSystem.hangOutBlocker(employeeID: employeeID, state: self, balance: balance)
    }

    /// Why mentoring somebody would be refused, or `nil`.
    public func mentorBlocker(employeeID: UUID, balance: BalanceConfig) -> String? {
        RelationshipSystem.mentorBlocker(employeeID: employeeID, state: self, balance: balance)
    }

    /// Whether the founder is standing in a networking room right now.
    public var isAtNetworkingEvent: Bool { networking.pendingEvent != nil }

    /// The founder's remaining slice of their own company, after every
    /// funding round and every slice signed over to somebody they met.
    public var founderEquity: Double { investors.equityRemaining }
}
