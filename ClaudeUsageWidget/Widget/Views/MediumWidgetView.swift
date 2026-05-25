import SwiftUI

struct MediumWidgetView: View {
    let usage: UsageData

    var body: some View {
        HStack(spacing: 0) {
            SmallWidgetView(usage: usage)
                .frame(maxWidth: .infinity)

            Divider()
                .padding(.vertical, 12)

            VStack(alignment: .leading, spacing: 6) {
                if usage.modelBreakdown.isEmpty {
                    SevenDayRowView(usage: usage)
                } else {
                    ForEach(usage.modelBreakdown.prefix(3), id: \.modelName) { model in
                        ModelRowView(model: model, limit: usage.messagesLimit)
                    }
                }

                Spacer(minLength: 0)

                Text("Updated \(usage.lastUpdated, style: .relative) ago")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct SevenDayRowView: View {
    let usage: UsageData

    private var fraction: Double {
        min(Double(usage.sevenDayUtilization) / 100.0, 1.0)
    }

    private var resetLabel: String {
        let now = Date()
        guard usage.sevenDayResetDate > now else { return "Resetting…" }
        let components = Calendar.current.dateComponents([.day, .hour], from: now, to: usage.sevenDayResetDate)
        let days = components.day ?? 0
        let hours = components.hour ?? 0
        if days > 0 { return "Resets in \(days)d" }
        return "Resets in \(max(hours, 1))h"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("7-day")
                    .font(.caption2)
                    .foregroundStyle(.primary)
                Spacer(minLength: 4)
                Text("\(usage.sevenDayUtilization)%")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.secondary.opacity(0.3))
                        .frame(height: 3)
                    Capsule()
                        .fill(.tint)
                        .frame(width: geo.size.width * fraction, height: 3)
                }
            }
            .frame(height: 3)
            Text(resetLabel)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
    }
}

private struct ModelRowView: View {
    let model: ModelUsage
    let limit: Int

    private var fraction: Double {
        guard limit > 0 else { return 0 }
        return min(Double(model.messagesUsed) / Double(limit), 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(displayName(model.modelName))
                    .font(.caption2)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text("\(model.messagesUsed)")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.secondary.opacity(0.2))
                        .frame(height: 3)
                    Capsule()
                        .fill(.tint)
                        .frame(width: geo.size.width * fraction, height: 3)
                }
            }
            .frame(height: 3)
        }
    }

    private func displayName(_ name: String) -> String {
        let stripped = name.replacingOccurrences(of: "claude-", with: "")
        let parts = stripped.split(separator: "-")
        guard !parts.isEmpty else { return name }
        let label = parts.first.map { $0.capitalized } ?? ""
        let version = parts.dropFirst().joined(separator: ".")
        return version.isEmpty ? label : "\(label) \(version)"
    }
}

#Preview {
    MediumWidgetView(usage: .placeholder())
        .frame(width: 329, height: 154)
}
