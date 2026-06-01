import SwiftUI
import AppIntents

struct SmallWidgetView: View {
    let usage: UsageData
    var showRefreshButton: Bool = true

    private var usageFraction: Double {
        min(Double(usage.fiveHourUtilization) / 100.0, 1.0)
    }

    private var timeUntilReset: String {
        guard let reset = usage.periodResetDate else { return "Reset time unknown" }
        let now = Date()
        guard reset > now else { return "Resetting…" }
        let components = Calendar.current.dateComponents([.day, .hour, .minute], from: now, to: reset)
        let days = components.day ?? 0
        let hours = components.hour ?? 0
        let minutes = components.minute ?? 0
        if days > 0 { return "Resets in \(days)d" }
        if hours > 0 { return "Resets in \(hours)h" }
        return "Resets in \(max(minutes, 1))m"
    }

    private var isStale: Bool {
        Date().timeIntervalSince(usage.lastUpdated) > RefreshPolicy.staleThreshold
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 4) {
                progressArc
                usageText
                resetLabel
                if isStale {
                    staleLabel
                }
            }
            .padding(10)

            if showRefreshButton {
                Button(intent: RefreshUsageIntent()) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(6)
            }
        }
    }

    private var progressArc: some View {
        ZStack {
            Circle()
                .stroke(.secondary.opacity(0.25), lineWidth: 6)
            if usageFraction > 0 {
                ArcShape(fraction: usageFraction)
                    .stroke(arcShading, style: StrokeStyle(lineWidth: 6, lineCap: .round))
            }
        }
        .frame(width: 52, height: 52)
    }

    private var arcShading: AnyShapeStyle {
        if usageFraction > 0.9 { AnyShapeStyle(.red) }
        else if usageFraction > 0.7 { AnyShapeStyle(.orange) }
        else { AnyShapeStyle(.tint) }
    }

    private var usageText: some View {
        Text("5h \(usage.fiveHourUtilization)%")
            .font(.system(.caption2, design: .monospaced))
            .foregroundStyle(.primary)
    }

    private var resetLabel: some View {
        let isOverdue = (usage.periodResetDate.map { $0 < Date() }) ?? false
        return Text(timeUntilReset)
            .font(.caption2)
            .foregroundStyle(isOverdue ? .orange : .secondary)
    }

    private var staleLabel: some View {
        Text("Stale data")
            .font(.system(size: 9))
            .foregroundStyle(.tertiary)
    }
}

private struct ArcShape: Shape {
    let fraction: Double
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 - 4
        path.addArc(center: center, radius: radius,
                    startAngle: .degrees(-90),
                    endAngle: .degrees(-90 + 360 * fraction),
                    clockwise: false)
        return path
    }
}

#Preview {
    SmallWidgetView(usage: .placeholder())
        .frame(width: 154, height: 154)
}
