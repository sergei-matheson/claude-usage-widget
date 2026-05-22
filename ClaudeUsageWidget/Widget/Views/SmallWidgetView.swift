import SwiftUI

struct SmallWidgetView: View {
    let usage: UsageData

    private var usageFraction: Double {
        guard usage.messagesLimit > 0 else { return 0 }
        return min(Double(usage.messagesUsed) / Double(usage.messagesLimit), 1.0)
    }

    private var daysUntilReset: Int {
        max(Calendar.current.dateComponents([.day], from: Date(), to: usage.periodResetDate).day ?? 0, 0)
    }

    private var isStale: Bool {
        Date().timeIntervalSince(usage.lastUpdated) > 1800
    }

    var body: some View {
        VStack(spacing: 4) {
            if usage.messagesLimit == 0 {
                unlimitedView
            } else {
                progressArc
                usageText
            }
            planBadge
            resetLabel
            if isStale {
                staleLabel
            }
        }
        .padding(10)
    }

    private var unlimitedView: some View {
        VStack(spacing: 2) {
            Image(systemName: "infinity")
                .font(.title2)
                .foregroundStyle(.tint)
            Text("\(usage.messagesUsed) used")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var progressArc: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 4

            var trackPath = Path()
            trackPath.addArc(center: center, radius: radius,
                             startAngle: .degrees(-90), endAngle: .degrees(270),
                             clockwise: false)
            context.stroke(trackPath, with: .color(.secondary.opacity(0.25)), lineWidth: 6)

            guard usageFraction > 0 else { return }
            var arcPath = Path()
            arcPath.addArc(center: center, radius: radius,
                           startAngle: .degrees(-90),
                           endAngle: .degrees(-90 + 360 * usageFraction),
                           clockwise: false)
            let arcColor: Color = usageFraction > 0.9 ? .red : usageFraction > 0.7 ? .orange : .accentColor
            context.stroke(arcPath, with: .color(arcColor),
                           style: StrokeStyle(lineWidth: 6, lineCap: .round))
        }
        .frame(width: 52, height: 52)
    }

    private var usageText: some View {
        Text("\(usage.messagesUsed)/\(usage.messagesLimit)")
            .font(.system(.caption2, design: .monospaced))
            .foregroundStyle(.primary)
    }

    private var planBadge: some View {
        Text(usage.planName)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.tint.opacity(0.15), in: Capsule())
            .foregroundStyle(.tint)
    }

    private var resetLabel: some View {
        Group {
            if usage.periodResetDate < Date() {
                Text("Resetting…")
                    .foregroundStyle(.orange)
            } else {
                Text("Resets in \(daysUntilReset)d")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption2)
    }

    private var staleLabel: some View {
        Text("Stale data")
            .font(.system(size: 9))
            .foregroundStyle(.tertiary)
    }
}

#Preview {
    SmallWidgetView(usage: .placeholder())
        .frame(width: 154, height: 154)
}
