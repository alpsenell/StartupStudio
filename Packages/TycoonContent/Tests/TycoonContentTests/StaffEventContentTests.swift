import Foundation
import Testing
import TycoonContent

/// The staff catalog's second acts and rules (WS-D): every follow-up
/// resolves to a def in the same catalog, and every def that is a second
/// act says which kind it belongs to.
@Suite("Staff event content")
struct StaffEventContentTests {
    let catalog: ContentCatalog

    init() throws {
        self.catalog = try ContentCatalog.loadBundled()
    }

    @Test("every staff follow-up resolves to a staff def")
    func followUpsResolve() {
        let ids = Set(catalog.staffEvents.map(\.id))
        for def in catalog.staffEvents {
            for outcome in [def.supportive, def.strict].compactMap({ $0 }) {
                guard let target = outcome.followUpEventID else { continue }
                #expect(ids.contains(target), "\(def.id) -> unknown \(target)")
                #expect(target != def.id, "\(def.id) follows up on itself")
            }
        }
    }

    @Test("second acts carry a kind and a policy block never names the same flag twice")
    func secondActsAndPoliciesAreWellFormed() {
        let targets = Set(catalog.staffEvents.flatMap { def in
            [def.supportive, def.strict].compactMap { $0?.followUpEventID }
        })
        for def in catalog.staffEvents where targets.contains(def.id) {
            #expect(def.kind != nil, "\(def.id) is a second act with no kind")
            #expect(def.policy == nil, "\(def.id) is a second act that could become a rule")
        }
        for def in catalog.staffEvents {
            guard let policy = def.policy else { continue }
            #expect(policy.supportiveFlag != policy.strictFlag, "\(def.id)")
            #expect(!policy.name.isEmpty, "\(def.id)")
        }
    }

    @Test("a second act with no supportive answer decodes as immediate")
    func immediateDecodes() throws {
        let def = try JSONDecoder().decode(StaffEventDef.self, from: Data("""
        {
          "id": "x_notice", "kind": "sideProject",
          "title": "{name} is leaving", "body": "Body.", "headline": "{name} left.",
          "weight": 1,
          "requires": { "flagsNone": ["ip_generous"], "flagsAll": ["ip_strict"] },
          "strict": { "label": "They go", "noticeReason": "Because.", "followUpEventID": "y", "followUpDelayDays": 3 }
        }
        """.utf8))
        #expect(def.isImmediate)
        #expect(def.kind == "sideProject")
        #expect(def.requires?.flagsNone == ["ip_generous"])
        #expect(def.requires?.flagsAll == ["ip_strict"])
        #expect(def.strict.noticeReason == "Because.")
        #expect(def.strict.followUpEventID == "y")
        #expect(def.strict.followUpDelayDays == 3)
    }
}
