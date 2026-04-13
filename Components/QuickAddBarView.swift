import SwiftUI

struct QuickAddBarView: View {
    let categories: [TransactionCategory]
    let onTap: (TransactionCategory) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Add")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(categories) { category in
                        Button {
                            onTap(category)
                        } label: {
                            HStack(spacing: 6) {
                                Text(category.icon)
                                Text(category.name)
                                    .font(.footnote.weight(.medium))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color(.secondarySystemBackground), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
