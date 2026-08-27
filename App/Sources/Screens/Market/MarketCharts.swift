import Charts
import SwiftUI
import TycoonEngine

// MARK: - Sparkline

/// Axis-free demand sparkline over a topic's weekly multipliers, with a
/// faint ×1.0 baseline for reference. With fewer than two samples it draws
/// the live value as a dashed level instead of an empty plot.
struct MarketSparkline: View {
    let series: [Double]
    let tint: Color

    var body: some View {
        Chart {
            RuleMark(y: .value("Baseline", 1.0))
                .foregroundStyle(.secondary.opacity(0.35))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))

            if series.count >= 2 {
                ForEach(Array(series.enumerated()), id: \.offset) { index, value in
                    LineMark(
                        x: .value("Week", Double(index)),
                        y: .value("Demand", value)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(tint)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                }
            } else if let current = series.first {
                RuleMark(y: .value("Demand", current))
                    .foregroundStyle(tint.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartXScale(domain: 0...Double(max(1, series.count - 1)))
        .chartYScale(domain: MarketChartScale.yDomain(for: series))
        .accessibilityHidden(true)
    }
}

// MARK: - Full topic chart

/// The 26-week demand line for one topic: a dashed ×1.0 baseline, the
/// weekly multiplier series, and boom/crash markers at the weeks the engine
/// recorded them. X is the absolute game week, matching the Finances chart.
struct TopicDemandChart: View {
    let points: [TopicChartPoint]
    let markers: [TopicEventMarker]
    let tint: Color

    var body: some View {
        Chart {
            RuleMark(y: .value("Baseline", 1.0))
                .foregroundStyle(.secondary.opacity(0.45))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .annotation(position: .top, alignment: .leading, spacing: 2) {
                    Text("×1.00 baseline")
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

            if points.count >= 2 {
                ForEach(points) { point in
                    AreaMark(
                        x: .value("Week", Double(point.week)),
                        yStart: .value("Baseline", 1.0),
                        yEnd: .value("Demand", point.value)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(tint.opacity(0.12))

                    LineMark(
                        x: .value("Week", Double(point.week)),
                        y: .value("Demand", point.value)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(tint)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
            } else {
                ForEach(points) { point in
                    PointMark(
                        x: .value("Week", Double(point.week)),
                        y: .value("Demand", point.value)
                    )
                    .foregroundStyle(tint)
                    .symbolSize(70)
                }
            }

            ForEach(markers) { marker in
                PointMark(
                    x: .value("Week", Double(marker.week)),
                    y: .value("Demand", marker.value)
                )
                .foregroundStyle(marker.kind.tint)
                .symbolSize(90)
                .annotation(position: marker.kind == .boom ? .top : .bottom, spacing: 3) {
                    Image(systemName: marker.kind.systemImage)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(marker.kind.tint)
                }
            }
        }
        .chartXAxisLabel("Game week", alignment: .trailing)
        .chartXScale(domain: xDomain)
        .chartYScale(domain: MarketChartScale.yDomain(for: points.map(\.value)))
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let multiplier = value.as(Double.self) {
                        Text(MarketFormat.multiplier(multiplier))
                            .font(.caption2)
                            .monospacedDigit()
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let week = value.as(Double.self) {
                        Text("\(Int(week))")
                            .font(.caption2)
                            .monospacedDigit()
                    }
                }
            }
        }
        .frame(height: 200)
        .accessibilityLabel(chartAccessibilityLabel)
    }

    /// Half-week padding keeps the end points (and their markers) off the
    /// plot edges for 1-point and 26-point series alike.
    private var xDomain: ClosedRange<Double> {
        let weeks = points.map(\.week)
        let lower = Double(weeks.min() ?? 1) - 0.5
        let upper = Double(weeks.max() ?? 1) + 0.5
        return lower...upper
    }

    private var chartAccessibilityLabel: String {
        let booms = markers.filter { $0.kind == .boom }.count
        let crashes = markers.filter { $0.kind == .crash }.count
        var label = "Demand chart, \(points.count) week\(points.count == 1 ? "" : "s")"
        if let first = points.first, let last = points.last, points.count >= 2 {
            label += ", from \(MarketFormat.multiplier(first.value)) to \(MarketFormat.multiplier(last.value))"
        }
        if booms > 0 { label += ", \(booms) boom\(booms == 1 ? "" : "s")" }
        if crashes > 0 { label += ", \(crashes) crash\(crashes == 1 ? "" : "es")" }
        return label
    }
}

// MARK: - Scale

enum MarketChartScale {
    /// A y range that always includes the ×1.0 baseline and keeps a little
    /// headroom, so flat series do not collapse to a zero-height band.
    static func yDomain(for values: [Double]) -> ClosedRange<Double> {
        let low = min(1.0, values.min() ?? 1.0)
        let high = max(1.0, values.max() ?? 1.0)
        let padding = max(0.05, (high - low) * 0.12)
        return max(0, low - padding)...(high + padding)
    }
}
