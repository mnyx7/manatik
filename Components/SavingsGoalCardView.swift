import SwiftUI

struct SavingsGoalCardView: View {
    let currentText: String
    let targetText: String
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Savings Goal")
                .font(.headline)

            HStack {
                Text("\(currentText) / \(targetText)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.subheadline.weight(.semibold))
            }

            ProgressView(value: progress)
                .tint(.blue)
        }
        .padding()
        .background(AppTheme.savingsColor.opacity(0.3), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#Preview {
    SavingsGoalCardView(currentText: "$420", targetText: "$1000", progress: 0.42)
        .padding()
}
