import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    var highlighted: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(color)
                Spacer()
                if highlighted {
                    Text("MEDIAN")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(color)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(color.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .minimumScaleFactor(0.65)
                .lineLimit(1)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(highlighted ? color.opacity(0.07) : Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(highlighted ? color.opacity(0.25) : .clear, lineWidth: 1)
        )
    }
}

struct ProbabilityCard: View {
    let title: String
    let value: Double
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(color)
                Spacer()
                Text(value, format: .percent.precision(.fractionLength(1)))
                    .font(.title2.weight(.bold).monospacedDigit())
                    .foregroundStyle(color)
            }
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.1))
                        .frame(height: 6)
                    Capsule()
                        .fill(color.gradient)
                        .frame(width: max(0, geo.size.width * CGFloat(value)), height: 6)
                        .animation(.spring(duration: 0.8), value: value)
                }
            }
            .frame(height: 6)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
