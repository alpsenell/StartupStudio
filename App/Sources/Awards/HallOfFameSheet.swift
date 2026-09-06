import SwiftUI
import TycoonContent
import TycoonEngine

// MARK: Iteration 8 — the Hall of Fame

/// Every product any of the player's companies ever shipped to a review
/// of 85 or better, best first, across the whole ledger.
struct HallOfFameSheet: View {
    let entries: [HallEntry]
    let content: ContentCatalog?
    var onClose: () -> Void = {}

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    if entries.isEmpty {
                        PixelPanel {
                            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                PixelText(text: "EMPTY", scale: 3, color: Theme.pixelInk.opacity(0.5))
                                Text("A product reviewed at \(AwardsJudge.hallThreshold) or better goes in here, from any company you ever ran, when that company ends.")
                                    .font(.footnote)
                                    .foregroundStyle(Theme.pixelInk.opacity(0.8))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    } else {
                        Text("\(entries.count) product\(entries.count == 1 ? "" : "s"), from every company you ever ran.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        ForEach(entries.sorted { $0.score != $1.score ? $0.score > $1.score : $0.productName < $1.productName }) { entry in
                            HallRow(entry: entry, topicName: content?.topic(entry.topicID)?.name ?? entry.topicID)
                        }
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Theme.screenBackground.ignoresSafeArea())
            .navigationTitle("Hall of Fame")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onClose)
                }
            }
        }
    }
}

private struct HallRow: View {
    let entry: HallEntry
    let topicName: String

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.md) {
            ProductBoxArtView(typeID: entry.typeID, topicID: entry.topicID, seed: entry.seed, size: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.productName)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Text("\(topicName) · \(entry.companyName) · year \(entry.year)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(entry.founderName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            PixelText(text: "\(entry.score)", scale: 3, color: Theme.pixelAccent)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.productName), \(entry.score), \(topicName), \(entry.companyName), year \(entry.year), \(entry.founderName)")
    }
}
